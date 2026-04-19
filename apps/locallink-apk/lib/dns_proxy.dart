import 'dart:io' as io;
import 'dart:typed_data' as types;
import 'package:flutter/material.dart' as flutter;
import 'package:locallink_mobile/registry_client.dart' as registry_client;
import 'package:locallink_mobile/config.dart';

class DnsProxy {
  late final registry_client.LocalDnsClient ipServerClient;
  final AppConfig config;
  DnsProxy({required this.config}) {
    ipServerClient = registry_client.LocalDnsClient(
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
    );
  }
  io.RawDatagramSocket? _server;

  String upstreamIp = "8.8.8.8";
  int upstreamPort = 53;

  int dnsPort = 5353;
  bool bindAllInterfaces = false;

  final flutter.ValueNotifier<List<String>> logs = flutter.ValueNotifier([]);

  bool isRunning = false;
  void log(String message) {
    final current = logs.value;
    final start = current.length > 8 ? current.length - 8 : 0;

    logs.value = [...current.sublist(start), message];
  }

  Future<void> start() async {
    if (isRunning) return;

    _server = await io.RawDatagramSocket.bind(
      bindAllInterfaces
          ? io.InternetAddress.anyIPv4
          : io.InternetAddress.loopbackIPv4,
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

  void _handlePacket(io.RawSocketEvent event) async {
    if (event != io.RawSocketEvent.read) return;

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
    final upstream = await io.RawDatagramSocket.bind(
      io.InternetAddress.anyIPv4,
      0,
    );

    upstream.send(query, io.InternetAddress(upstreamIp), upstreamPort);

    upstream.listen((event) {
      if (event == io.RawSocketEvent.read) {
        final response = upstream.receive();
        if (response != null) {
          _server!.send(response.data, datagram.address, datagram.port);
        }
        upstream.close();
      }
    });
  }

  String extractDomain(types.Uint8List data) {
    int i = 12;
    List<String> labels = [];

    while (data[i] != 0) {
      int length = data[i++];
      labels.add(String.fromCharCodes(data.sublist(i, i + length)));
      i += length;
    }

    return labels.join('.');
  }

  types.Uint8List buildNxDomainResponse(types.Uint8List query) {
    final response = types.Uint8List.fromList(query);

    // Set response flags: QR=1, RCODE=3 (NXDOMAIN)
    response[2] = 0x81;
    response[3] = 0x83;

    // No answers
    response[6] = 0x00;
    response[7] = 0x00;

    return response;
  }

  types.Uint8List buildResponse(types.Uint8List query, String ip) {
    final response = types.Uint8List.fromList(query);

    response[2] = 0x81;
    response[3] = 0x80;
    response[6] = 0x00;
    response[7] = 0x01;

    final answer = types.BytesBuilder();

    answer.add([0xC0, 0x0C]);
    answer.add([0x00, 0x01]);
    answer.add([0x00, 0x01]);
    answer.add([0x00, 0x00, 0x00, 0x3C]);
    answer.add([0x00, 0x04]);
    answer.add(ip.split('.').map(int.parse).toList());

    return types.Uint8List.fromList([...response, ...answer.toBytes()]);
  }
}
