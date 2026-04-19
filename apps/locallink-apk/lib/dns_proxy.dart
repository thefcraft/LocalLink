import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'registry_client.dart';

final ipServerClient = LocalDnsClient(
  baseUrl: 'https://ip-finder-server-8nb4.vercel.app',
  apiKey:
      'sexy123asshole123-love-for-her-should-be-killed-as-i-am-nothing-for-her-re(z)-be-real',
);

class DnsProxy {
  RawDatagramSocket? _server;

  String upstreamIp = "8.8.8.8";
  int upstreamPort = 53;

  int dnsPort = 5353;
  bool bindAllInterfaces = false;

  final ValueNotifier<List<String>> logs = ValueNotifier([]);

  bool isRunning = false;
  void log(String message) {
    final current = logs.value;
    final start = current.length > 8 ? current.length - 8 : 0;

    logs.value = [...current.sublist(start), message];
  }

  Future<void> start() async {
    if (isRunning) return;

    _server = await RawDatagramSocket.bind(
      bindAllInterfaces
          ? InternetAddress.anyIPv4
          : InternetAddress.loopbackIPv4,
      dnsPort,
    );

    isRunning = true;
    log("Started DNS Proxy on 127.0.0.1:$dnsPort");

    _server!.listen(_handlePacket);
  }

  void stop() {
    _server?.close();
    isRunning = false;
    log("Stopped DNS Proxy");
  }

  void _handlePacket(RawSocketEvent event) async {
    if (event != RawSocketEvent.read) return;

    final datagram = _server!.receive();
    if (datagram == null) return;

    final query = datagram.data;
    final domain = extractDomain(query);

    log("Query: $domain");

    // 👉 Handle .local domains via API
    if (domain.endsWith('.local')) {
      final cleanName = domain.substring(0, domain.length - '.local'.length);
      try {
        final ip = await ipServerClient.resolve(cleanName);
        if (ip != null) {
          log("API → $domain = $ip");

          final response = buildResponse(query, ip);
          _server!.send(response, datagram.address, datagram.port);
        } else {
          log("API NXDOMAIN → $domain");

          final response = buildNxDomainResponse(query);
          _server!.send(response, datagram.address, datagram.port);
        }
      } catch (e) {
        log("API error → NXDOMAIN");

        final response = buildNxDomainResponse(query);
        _server!.send(response, datagram.address, datagram.port);
      }
      return;
    }

    // Forward to upstream DNS
    final upstream = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    upstream.send(query, InternetAddress(upstreamIp), upstreamPort);

    upstream.listen((event) {
      if (event == RawSocketEvent.read) {
        final response = upstream.receive();
        if (response != null) {
          _server!.send(response.data, datagram.address, datagram.port);
        }
        upstream.close();
      }
    });
  }

  String extractDomain(Uint8List data) {
    int i = 12;
    List<String> labels = [];

    while (data[i] != 0) {
      int length = data[i++];
      labels.add(String.fromCharCodes(data.sublist(i, i + length)));
      i += length;
    }

    return labels.join('.');
  }

  Uint8List buildNxDomainResponse(Uint8List query) {
    final response = Uint8List.fromList(query);

    // Set response flags: QR=1, RCODE=3 (NXDOMAIN)
    response[2] = 0x81;
    response[3] = 0x83;

    // No answers
    response[6] = 0x00;
    response[7] = 0x00;

    return response;
  }

  Uint8List buildResponse(Uint8List query, String ip) {
    final response = Uint8List.fromList(query);

    response[2] = 0x81;
    response[3] = 0x80;
    response[6] = 0x00;
    response[7] = 0x01;

    final answer = BytesBuilder();

    answer.add([0xC0, 0x0C]);
    answer.add([0x00, 0x01]);
    answer.add([0x00, 0x01]);
    answer.add([0x00, 0x00, 0x00, 0x3C]);
    answer.add([0x00, 0x04]);
    answer.add(ip.split('.').map(int.parse).toList());

    return Uint8List.fromList([...response, ...answer.toBytes()]);
  }
}
