import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:locallink_mobile/config.dart';
import 'package:locallink_mobile/dns_proxy.dart' as dns_proxy;

class Home extends StatefulWidget {
  final AppConfig config;
  const Home({super.key, required this.config});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final dns_proxy.DnsProxy proxy;
  @override
  void initState() {
    super.initState();
    proxy = dns_proxy.DnsProxy(config: widget.config);
    loadIps();
  }

  final domainCtrl = TextEditingController();
  final ipCtrl = TextEditingController();

  final dnsIpCtrl = TextEditingController(text: "8.8.8.8");
  final dnsPortCtrl = TextEditingController(text: "53");
  final appPortCtrl = TextEditingController(text: "5353");
  final serviceNameCtrl = TextEditingController();
  bool autoRegister = false;
  Timer? heartbeatTimer;

  List<(String interface, String ip)> availableIps = [];
  String? selectedIp;
  bool loadingIps = false;

  bool bindAllInterfaces = false; // false = 127.0.0.1, true = 0.0.0.0

  void refresh() => setState(() {});

  Future<void> loadIps() async {
    if (loadingIps) return;
    setState(() => loadingIps = true);

    final ips = <(String interface, String ip)>[];
    try {
      for (var interface in await io.NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.isLoopback) continue;
          if (addr.type == io.InternetAddressType.IPv6) continue;
          ips.add((interface.name, addr.address));
        }
      }

      proxy.log("Loaded IPs: $ips");
    } catch (e) {
      proxy.log("Failed to load IPs: $e");
    }

    setState(() {
      availableIps = ips;
      selectedIp = ips.isNotEmpty ? ips.first.$2 : null;
      loadingIps = false;
    });
  }

  Future<void> registerSelf(String name, String ip) async {
    final ok = await proxy.ipServerClient.register(
      name: name,
      ip: ip,
      ttl: 90,
      strict: false,
    );
    if (ok) {
      proxy.log("Registered: $name → $ip");
    } else {
      proxy.log("Register failed");
    }
  }

  void startHeartbeat() async {
    heartbeatTimer?.cancel();
    final name = serviceNameCtrl.text.trim();
    if (name.isEmpty) {
      proxy.log("Service name is empty");
      setState(() => autoRegister = false);
      heartbeatTimer = null;
      return;
    }
    final selectedIp = this.selectedIp;
    if (selectedIp == null) {
      proxy.log("Failed to get IP");
      setState(() => autoRegister = false);
      heartbeatTimer = null;
      return;
    }
    proxy.log("starting heartbeat...");
    // check if name exists and not equal to ip then return
    final ok = await proxy.ipServerClient.register(
      name: name,
      ip: selectedIp,
      ttl: 90,
      strict: true, // strict flag
    );
    if (ok) {
      proxy.log("Registered: $name → $selectedIp");
    } else {
      proxy.log("Name already taken");
      setState(() => autoRegister = false);
      heartbeatTimer = null;
      return;
    }
    heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await registerSelf(name, selectedIp);
    });
    
    proxy.log("Heartbeat started");
  }

  void stopHeartbeat() {
    heartbeatTimer?.cancel();
    heartbeatTimer = null;
    proxy.log("Heartbeat stopped");
  }

  @override
  void dispose() {
    heartbeatTimer?.cancel();
    serviceNameCtrl.dispose();
    proxy.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DNS Proxy")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            /// DNS SETTINGS
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: dnsIpCtrl,
                    decoration: const InputDecoration(labelText: "DNS IP"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: dnsPortCtrl,
                    decoration: const InputDecoration(labelText: "DNS Port"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: appPortCtrl,
              decoration: const InputDecoration(labelText: "Port"),
            ),
            Row(
              children: [
                const Text("Bind to all interfaces (0.0.0.0): "),
                const SizedBox(width: 10),
                Switch(
                  value: bindAllInterfaces,
                  onChanged: (val) {
                    setState(() => bindAllInterfaces = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: serviceNameCtrl,
              decoration: const InputDecoration(labelText: "Service Name"),
            ),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedIp,
                    items: availableIps
                        .map(
                          (ip) => DropdownMenuItem(
                            value: ip.$2,
                            child: Text('${ip.$1} => ${ip.$2}'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() => selectedIp = val);
                    },
                    decoration: const InputDecoration(labelText: "Select IP"),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: loadingIps
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.refresh),
                  onPressed: loadIps,
                ),
              ],
            ),

            Row(
              children: [
                const Text("Auto Register: "),
                const SizedBox(width: 10),
                Switch(
                  value: autoRegister,
                  onChanged: (val) {
                    setState(() => autoRegister = val);
                    if (val) {
                      startHeartbeat();
                    } else {
                      stopHeartbeat();
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// CONTROLS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    proxy.upstreamIp = dnsIpCtrl.text;
                    proxy.upstreamPort = int.parse(dnsPortCtrl.text);
                    proxy.dnsPort = int.parse(appPortCtrl.text);
                    proxy.bindAllInterfaces = bindAllInterfaces;
                    proxy.log("Updated upstream DNS");
                    await proxy.start();
                    refresh();
                  },
                  child: const Text("Start"),
                ),
                ElevatedButton(
                  onPressed: () {
                    proxy.stop();
                    refresh();
                  },
                  child: const Text("Stop"),
                ),
              ],
            ),

            const Divider(),

            /// LOGS
            ValueListenableBuilder<List<String>>(
              valueListenable: proxy.logs,
              builder: (context, logs, _) {
                return Expanded(
                  child: ListView(
                    children: logs
                        .map(
                          (e) => Text(e, style: const TextStyle(fontSize: 12)),
                        )
                        .toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
