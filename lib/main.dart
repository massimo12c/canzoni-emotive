import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const CanzoniEmotiveApp());
}

class CanzoniEmotiveApp extends StatelessWidget {
  const CanzoniEmotiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Canzoni Emotive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C4DFF),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F2FF),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();

  bool _isRecording = false;
  bool _hasRecording = false;
  String? _recordedPath;
  String _status = 'Premi il pulsante per registrare un clip audio breve.';

  @override
  void dispose() {
    _searchController.dispose();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(() {
          _status = 'Permesso microfono negato.';
        });
        return;
      }

      String path;

      if (kIsWeb) {
        path = 'clip_audio_web.m4a';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        path = '${dir.path}/clip_audio.m4a';
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _hasRecording = false;
        _recordedPath = null;
        _status = 'Registrazione in corso... parla o fai sentire la musica.';
      });
    } catch (e) {
      setState(() {
        _status = 'Errore avvio registrazione: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();

      setState(() {
        _isRecording = false;
        _recordedPath = path;
        _hasRecording = path != null;
        _status = path != null
            ? 'Clip registrato correttamente.'
            : 'Registrazione non salvata.';
      });
    } catch (e) {
      setState(() {
        _isRecording = false;
        _status = 'Errore stop registrazione: $e';
      });
    }
  }

  Future<void> _playRecording() async {
    try {
      if (_recordedPath == null) {
        setState(() {
          _status = 'Nessun clip da ascoltare.';
        });
        return;
      }

      await _player.stop();

      if (kIsWeb) {
        await _player.setUrl(_recordedPath!);
      } else {
        await _player.setFilePath(_recordedPath!);
      }

      await _player.play();

      setState(() {
        _status = 'Riproduzione clip audio.';
      });
    } catch (e) {
      setState(() {
        _status = 'Errore riproduzione: $e';
      });
    }
  }

  Future<void> _openYoutubeSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _status = 'Scrivi titolo o artista prima di cercare su YouTube.';
      });
      return;
    }

    final uri = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}',
    );

    await _openUrl(uri);
  }

  Future<void> _openSpotifySearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _status = 'Scrivi titolo o artista prima di cercare su Spotify.';
      });
      return;
    }

    final uri = Uri.parse(
      'https://open.spotify.com/search/${Uri.encodeComponent(query)}',
    );

    await _openUrl(uri);
  }

  Future<void> _openUrl(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        setState(() {
          _status = 'Non riesco ad aprire il link.';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Errore apertura link: $e';
      });
    }
  }

  Future<void> _clearAll() async {
    await _player.stop();
    _searchController.clear();

    setState(() {
      _isRecording = false;
      _hasRecording = false;
      _recordedPath = null;
      _status = 'Pulito.';
    });
  }

  bool get _isAppleMobile {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canzoni Emotive'),
        centerTitle: true,
        backgroundColor: const Color(0xFFEDE7FF),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modalità Trova musica',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF24145A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Registra un breve clip audio e poi cerca manualmente il brano su YouTube o Spotify.',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A153B), Color(0xFF232D63)],
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 56,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isRecording
                                ? 'Registrazione in corso'
                                : _hasRecording
                                    ? 'Clip pronto'
                                    : 'Pronto a registrare',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                _isRecording ? _stopRecording : _startRecording,
                            style: FilledButton.styleFrom(
                              backgroundColor: _isRecording
                                  ? Colors.red
                                  : const Color(0xFF18A66A),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            icon: Icon(
                              _isRecording ? Icons.stop : Icons.mic,
                              color: Colors.white,
                            ),
                            label: Text(
                              _isRecording ? 'Ferma' : 'Trova musica',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _hasRecording ? _playRecording : null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text(
                              'Ascolta clip',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cerca il brano',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF24145A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Scrivi titolo o artista',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openYoutubeSearch,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D6D),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text(
                          'Ascolta su YouTube',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openSpotifySearch,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        icon: const Icon(Icons.headphones),
                        label: const Text(
                          'Cerca su Spotify',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _clearAll,
                        child: const Text('Pulisci'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (kIsWeb || _isAppleMobile)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Questa versione registra un clip audio ma non riconosce automaticamente il brano. Per il riconoscimento vero serve una API esterna.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBFF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}