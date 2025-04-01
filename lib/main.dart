import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Trigger rebuild for GitHub CI

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iPad Stream Viewer',
      theme: ThemeData.dark(),
      home: const StreamViewer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class StreamViewer extends StatefulWidget {
  const StreamViewer({super.key});

  @override
  State<StreamViewer> createState() => _StreamViewerState();
}

class _StreamViewerState extends State<StreamViewer> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }

  Future<void> _startStream() async {
    await _remoteRenderer.initialize();

    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    };

    final pc = await createPeerConnection(config);
    _peerConnection = pc;

    pc.onTrack = (event) {
      if (event.track.kind == 'video') {
        setState(() {
          _remoteRenderer.srcObject = event.streams.first;
        });
      }
    };

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    final response = await http.post(
      Uri.parse('http://192.168.0.132:8080/offer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sdp': offer.sdp,
        'type': offer.type,
      }),
    );

    final answer = jsonDecode(response.body);
    await pc.setRemoteDescription(
      RTCSessionDescription(answer['sdp'], answer['type']),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: RTCVideoView(_remoteRenderer),
      ),
    );
  }
}
