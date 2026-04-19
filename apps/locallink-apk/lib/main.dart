import 'package:flutter/material.dart';
import 'dns_proxy.dart';

void main() {
  runApp(const MyApp());
}

final proxy = DnsProxy();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Home());
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final domainCtrl = TextEditingController();
  final ipCtrl = TextEditingController();

  final dnsIpCtrl = TextEditingController(text: "8.8.8.8");
  final dnsPortCtrl = TextEditingController(text: "53");
  final appPortCtrl = TextEditingController(text: "5353");

  bool bindAllInterfaces = false; // false = 127.0.0.1, true = 0.0.0.0

  void refresh() => setState(() {});

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
