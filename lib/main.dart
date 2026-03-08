import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const SongEmotionApp());
}

class SongEmotionApp extends StatelessWidget {
  const SongEmotionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Canzoni Emotive',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C4DFF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F4FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Color(0xFF24164C),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3EEFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFF6C4DFF),
              width: 1.5,
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class SongAnalysis {
  final String title;
  final String artist;
  final String emotion;
  final String theme;
  final String atmosphere;
  final String meaning;
  final String description;
  final String link;
  final String coverUrl;

  SongAnalysis({
    required this.title,
    required this.artist,
    required this.emotion,
    required this.theme,
    required this.atmosphere,
    required this.meaning,
    required this.description,
    required this.link,
    required this.coverUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'emotion': emotion,
      'theme': theme,
      'atmosphere': atmosphere,
      'meaning': meaning,
      'description': description,
      'link': link,
      'coverUrl': coverUrl,
    };
  }

  factory SongAnalysis.fromMap(Map<String, dynamic> map) {
    return SongAnalysis(
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      emotion: map['emotion'] ?? '',
      theme: map['theme'] ?? '',
      atmosphere: map['atmosphere'] ?? '',
      meaning: map['meaning'] ?? '',
      description: map['description'] ?? '',
      link: map['link'] ?? '',
      coverUrl: map['coverUrl'] ?? '',
    );
  }
}

class RecognitionResult {
  final String title;
  final String artist;
  final String album;
  final String songLink;
  final String spotifyUrl;
  final String appleMusicUrl;
  final String artworkUrl;
  final String timecode;

  const RecognitionResult({
    required this.title,
    required this.artist,
    required this.album,
    required this.songLink,
    required this.spotifyUrl,
    required this.appleMusicUrl,
    required this.artworkUrl,
    required this.timecode,
  });

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    final spotify = json['spotify'] as Map<String, dynamic>?;
    final appleMusic = json['apple_music'] as Map<String, dynamic>?;
    final artwork = appleMusic?['artwork'] as Map<String, dynamic>?;

    String artworkUrl = '';
    if (artwork != null && artwork['url'] is String) {
      artworkUrl = (artwork['url'] as String)
          .replaceAll('{w}', '1000')
          .replaceAll('{h}', '1000');
    }

    return RecognitionResult(
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      album: json['album']?.toString() ?? '',
      songLink: json['song_link']?.toString() ?? '',
      spotifyUrl: spotify?['external_urls']?['spotify']?.toString() ?? '',
      appleMusicUrl: appleMusic?['url']?.toString() ?? '',
      artworkUrl: artworkUrl,
      timecode: json['timecode']?.toString() ?? '',
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController artistController = TextEditingController();
  final TextEditingController lyricsController = TextEditingController();
  final TextEditingController linkController = TextEditingController();
  final TextEditingController apiTokenController = TextEditingController();

  final AudioRecorder recorder = AudioRecorder();

  String emotion = '';
  String meaning = '';
  String theme = '';
  String atmosphere = '';
  String description = '';
  String coverUrl = '';

  bool isLoadingCover = false;
  bool isRecording = false;
  bool isRecognizing = false;

  int recordingSecondsLeft = 12;
  String recordedFilePath = '';

  String recognitionMessage =
      'Premi il pulsante Trova musica per registrare e provare a riconoscere il brano.';

  RecognitionResult? recognitionResult;

  Timer? recordingTimer;

  final List<SongAnalysis> history = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
    loadApiToken();
  }

  Future<void> loadApiToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('audd_api_token') ?? '';
    apiTokenController.text = token;

    if (!mounted) return;
    setState(() {});
  }

  Future<void> saveApiToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audd_api_token', apiTokenController.text.trim());
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('song_history') ?? [];

    final loaded = saved.map((item) {
      final map = jsonDecode(item) as Map<String, dynamic>;
      return SongAnalysis.fromMap(map);
    }).toList();

    if (!mounted) return;

    setState(() {
      history
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = history.map((item) => jsonEncode(item.toMap())).toList();
    await prefs.setStringList('song_history', encoded);
  }

  Future<void> analyzeSong() async {
    final text = lyricsController.text.toLowerCase();
    final rawTitle = titleController.text.trim();
    final rawArtist = artistController.text.trim();
    final link = linkController.text.trim();

    if (rawTitle.isEmpty && rawArtist.isEmpty && text.isEmpty) {
      _showSnack('Inserisci almeno un dato della canzone');
      return;
    }

    final title = rawTitle.isEmpty ? 'Senza titolo' : rawTitle;
    final artist = rawArtist.isEmpty ? 'Artista non indicato' : rawArtist;

    setState(() {
      isLoadingCover = true;
    });

    String detectedEmotion = 'Riflessiva';
    String detectedMeaning =
        'La canzone sembra raccontare emozioni personali e un vissuto interiore.';
    String detectedTheme = 'Emozioni e pensieri';
    String detectedAtmosphere = 'Intensa';

    if (text.contains('amore') ||
        text.contains('cuore') ||
        text.contains('baci') ||
        text.contains('ti amo') ||
        text.contains('abbracci')) {
      detectedEmotion = 'Romantica';
      detectedMeaning =
          'La canzone parla soprattutto di amore, legame emotivo e desiderio.';
      detectedTheme = 'Amore';
      detectedAtmosphere = 'Dolce';
    }

    if (text.contains('piango') ||
        text.contains('lacrime') ||
        text.contains('addio') ||
        text.contains('mancanza') ||
        text.contains('perso') ||
        text.contains('solo')) {
      detectedEmotion = 'Triste';
      detectedMeaning =
          'Il testo trasmette dolore, perdita o nostalgia verso una persona o un momento.';
      detectedTheme = 'Perdita e nostalgia';
      detectedAtmosphere = 'Malinconica';
    }

    if (text.contains('forza') ||
        text.contains('vinco') ||
        text.contains('lotta') ||
        text.contains('rialz') ||
        text.contains('resisto') ||
        text.contains('combatto')) {
      detectedEmotion = 'Motivante';
      detectedMeaning =
          'La canzone comunica reazione, crescita personale e voglia di andare avanti.';
      detectedTheme = 'Riscatto';
      detectedAtmosphere = 'Carica';
    }

    if (text.contains('notte') ||
        text.contains('buio') ||
        text.contains('solitudine') ||
        text.contains('silenzio')) {
      detectedAtmosphere = 'Profonda e notturna';
    }

    if (text.contains('strada') ||
        text.contains('cammino') ||
        text.contains('viaggio')) {
      detectedTheme = 'Percorso interiore';
    }

    final generatedDescription = buildSmartDescription(
      title: title,
      artist: artist,
      lyrics: text,
      emotion: detectedEmotion,
      theme: detectedTheme,
      atmosphere: detectedAtmosphere,
      meaning: detectedMeaning,
    );

    final fetchedCover = await fetchSongCover(title, artist);

    final analysis = SongAnalysis(
      title: title,
      artist: artist,
      emotion: detectedEmotion,
      theme: detectedTheme,
      atmosphere: detectedAtmosphere,
      meaning: detectedMeaning,
      description: generatedDescription,
      link: link,
      coverUrl: fetchedCover,
    );

    if (!mounted) return;

    setState(() {
      emotion = detectedEmotion;
      meaning = detectedMeaning;
      theme = detectedTheme;
      atmosphere = detectedAtmosphere;
      description = generatedDescription;
      coverUrl = fetchedCover;
      isLoadingCover = false;
      history.insert(0, analysis);
    });

    await saveHistory();
  }

  Future<String> fetchSongCover(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$title $artist');
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=$query&entity=song&limit=1',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'];
        if (results is List && results.isNotEmpty) {
          final artwork = results.first['artworkUrl100'];
          if (artwork is String && artwork.isNotEmpty) {
            return artwork.replaceAll('100x100bb', '600x600bb');
          }
        }
      }
    } catch (_) {}

    return '';
  }

  String buildSmartDescription({
    required String title,
    required String artist,
    required String lyrics,
    required String emotion,
    required String theme,
    required String atmosphere,
    required String meaning,
  }) {
    String focus =
        'Il brano "$title" di $artist comunica una sensazione $emotion e si muove soprattutto sul tema "$theme". L’atmosfera generale è $atmosphere.';

    String emotionalLayer =
        ' In modo semplice, il messaggio sembra questo: $meaning';

    String deeperLayer =
        ' La canzone sembra voler trasformare emozioni private in qualcosa che chi ascolta può sentire come proprio.';

    if (lyrics.contains('strada') ||
        lyrics.contains('cammino') ||
        lyrics.contains('viaggio')) {
      deeperLayer =
          ' Il testo usa anche l’idea del cammino o della strada, quindi può parlare di cambiamento, crescita o ricerca personale.';
    }

    if (lyrics.contains('mare') ||
        lyrics.contains('vento') ||
        lyrics.contains('pioggia') ||
        lyrics.contains('cielo')) {
      deeperLayer =
          ' Nel testo compaiono immagini della natura, quindi la canzone prova a far sentire le emozioni attraverso scenari e sensazioni visive.';
    }

    if (lyrics.contains('tu') && lyrics.contains('io')) {
      deeperLayer +=
          ' La presenza forte di “io” e “tu” fa pensare a un rapporto diretto, intimo, quasi come una confessione.';
    }

    if (lyrics.contains('sempre') || lyrics.contains('mai')) {
      deeperLayer +=
          ' L’uso di parole assolute come “sempre” o “mai” fa sentire la canzone più intensa e definitiva.';
    }

    if (emotion == 'Triste') {
      deeperLayer +=
          ' Nel complesso lascia il segno perché non parla solo di dolore: prova anche a dare forma alla mancanza.';
    }

    if (emotion == 'Motivante') {
      deeperLayer +=
          ' Il suo punto forte è l’energia di reazione: non resta ferma nel problema, ma spinge verso un cambiamento.';
    }

    if (emotion == 'Romantica') {
      deeperLayer +=
          ' L’effetto finale è quello di un coinvolgimento affettivo forte, fatto di desiderio, vicinanza e bisogno emotivo.';
    }

    return '$focus$emotionalLayer$deeperLayer';
  }

  Future<void> openSongLink() async {
    final raw = linkController.text.trim();
    final title = titleController.text.trim();
    final artist = artistController.text.trim();

    Uri? uri;

    if (raw.isNotEmpty) {
      final normalized = raw.startsWith('http://') || raw.startsWith('https://')
          ? raw
          : 'https://$raw';

      uri = Uri.tryParse(normalized);

      if (uri == null || !uri.hasScheme) {
        _showSnack('Link non valido');
        return;
      }
    } else {
      final query = [title, artist].where((e) => e.isNotEmpty).join(' ');
      if (query.isEmpty) {
        _showSnack('Inserisci almeno titolo o artista per cercare la canzone');
        return;
      }

      uri = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}',
      );
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showSnack('Non riesco ad aprire il link');
    }
  }

  Future<void> searchSongOnSpotify() async {
    final title = titleController.text.trim();
    final artist = artistController.text.trim();
    final query = [title, artist].where((e) => e.isNotEmpty).join(' ');

    if (query.isEmpty) {
      _showSnack('Inserisci almeno titolo o artista');
      return;
    }

    final uri = Uri.parse(
      'https://open.spotify.com/search/${Uri.encodeComponent(query)}',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showSnack('Non riesco ad aprire Spotify');
    }
  }

  Future<String> _buildRecordingPath() async {
    final directory = await getTemporaryDirectory();
    return '${directory.path}/song_clip_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> startShazamLikeRecording() async {
    try {
      if (kIsWeb) {
        _showSnack('Questa versione è pensata per macOS o mobile');
        return;
      }

      if (await recorder.hasPermission() == false) {
        _showSnack('Permesso microfono non concesso');
        return;
      }

      final path = await _buildRecordingPath();

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      recordingTimer?.cancel();

      setState(() {
        isRecording = true;
        isRecognizing = false;
        recordingSecondsLeft = 12;
        recordedFilePath = '';
        recognitionResult = null;
        recognitionMessage =
            'Sto ascoltando... avvicina la musica al microfono per 12 secondi.';
      });

      recordingTimer =
          Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) return;

        if (recordingSecondsLeft <= 1) {
          timer.cancel();
          await stopShazamLikeRecording(
            auto: true,
            recognizeAfterStop: true,
          );
        } else {
          setState(() {
            recordingSecondsLeft -= 1;
          });
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isRecording = false;
        recognitionMessage =
            'Non sono riuscito ad avviare la registrazione. Controlla microfono e permessi.';
      });
    }
  }

  Future<void> stopShazamLikeRecording({
    bool auto = false,
    bool recognizeAfterStop = false,
  }) async {
    try {
      recordingTimer?.cancel();
      final path = await recorder.stop();

      if (!mounted) return;

      setState(() {
        isRecording = false;
        recordingSecondsLeft = 12;
        recordedFilePath = path ?? '';
        recognitionMessage = path == null || path.isEmpty
            ? 'Registrazione non trovata. Riprova.'
            : auto
                ? 'Clip audio pronta. Ora provo a riconoscere il brano...'
                : 'Registrazione fermata. Clip pronta per il riconoscimento.';
      });

      if (recognizeAfterStop && path != null && path.isNotEmpty) {
        await recognizeRecordedSong();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isRecording = false;
        recordingSecondsLeft = 12;
        recognitionMessage = 'Errore durante la chiusura della registrazione.';
      });
    }
  }

  Future<void> recognizeRecordedSong() async {
    final token = apiTokenController.text.trim();

    if (token.isEmpty) {
      _showSnack('Inserisci prima la tua API key AudD');
      return;
    }

    if (recordedFilePath.isEmpty) {
      _showSnack('Prima registra un clip audio');
      return;
    }

    final file = File(recordedFilePath);
    if (!await file.exists()) {
      _showSnack('File audio non trovato');
      return;
    }

    await saveApiToken();

    setState(() {
      isRecognizing = true;
      recognitionMessage = 'Sto cercando il brano...';
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.audd.io/'),
      );

      request.fields['api_token'] = token;
      request.fields['return'] = 'apple_music,spotify';
      request.fields['market'] = 'it';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          recordedFilePath,
          filename: 'song_clip.m4a',
        ),
      );

      final streamed = await request.send();
      final responseText = await streamed.stream.bytesToString();
      final data = jsonDecode(responseText) as Map<String, dynamic>;

      if (streamed.statusCode != 200) {
        setState(() {
          isRecognizing = false;
          recognitionMessage =
              'Errore server (${streamed.statusCode}). Controlla API key o riprova.';
        });
        return;
      }

      if (data['status'] != 'success') {
        setState(() {
          isRecognizing = false;
          recognitionMessage = 'Riconoscimento non riuscito.';
        });
        return;
      }

      final resultJson = data['result'];
      if (resultJson == null) {
        setState(() {
          isRecognizing = false;
          recognitionResult = null;
          recognitionMessage =
              'Nessuna canzone trovata. Prova con volume più alto o un punto più chiaro del brano.';
        });
        return;
      }

      final result =
          RecognitionResult.fromJson(resultJson as Map<String, dynamic>);

      final fetchedCover = result.artworkUrl.isNotEmpty
          ? result.artworkUrl
          : await fetchSongCover(result.title, result.artist);

      if (!mounted) return;

      setState(() {
        isRecognizing = false;
        recognitionResult = result;
        titleController.text = result.title;
        artistController.text = result.artist;
        coverUrl = fetchedCover;

        if (linkController.text.trim().isEmpty && result.songLink.isNotEmpty) {
          linkController.text = result.songLink;
        }

        recognitionMessage =
            'Brano trovato: ${result.title} - ${result.artist}';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isRecognizing = false;
        recognitionMessage =
            'Errore durante il riconoscimento. Controlla internet, API key e riprova.';
      });
    }
  }

  Future<void> openRecognitionBestLink() async {
    if (recognitionResult == null) {
      _showSnack('Nessun brano riconosciuto');
      return;
    }

    final result = recognitionResult!;

    final raw = result.spotifyUrl.isNotEmpty
        ? result.spotifyUrl
        : result.appleMusicUrl.isNotEmpty
            ? result.appleMusicUrl
            : result.songLink;

    if (raw.isEmpty) {
      _showSnack('Nessun link disponibile');
      return;
    }

    final uri = Uri.parse(raw);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok) {
      _showSnack('Non riesco ad aprire il link');
    }
  }

  Future<void> clearAllHistory() async {
    setState(() {
      history.clear();
    });
    await saveHistory();
  }

  void clearFields() {
    setState(() {
      titleController.clear();
      artistController.clear();
      lyricsController.clear();
      linkController.clear();
      emotion = '';
      meaning = '';
      theme = '';
      atmosphere = '';
      description = '';
      coverUrl = '';
      recognitionResult = null;
      recordedFilePath = '';
      recognitionMessage =
          'Premi il pulsante Trova musica per registrare e provare a riconoscere il brano.';
    });
  }

  void loadFromHistory(SongAnalysis item) {
    setState(() {
      titleController.text = item.title == 'Senza titolo' ? '' : item.title;
      artistController.text =
          item.artist == 'Artista non indicato' ? '' : item.artist;
      linkController.text = item.link;
      emotion = item.emotion;
      theme = item.theme;
      atmosphere = item.atmosphere;
      meaning = item.meaning;
      description = item.description;
      coverUrl = item.coverUrl;
    });
  }

  Future<void> removeHistoryItem(int index) async {
    setState(() {
      history.removeAt(index);
    });
    await saveHistory();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Widget buildGradientHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C4DFF), Color(0xFFAA7BFF), Color(0xFF4CC9F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C4DFF).withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Icon(Icons.music_note_rounded,
                    color: Colors.white, size: 28),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Canzoni Emotive',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Analizza testi, salva lo storico, apri YouTube o Spotify e usa Trova musica per riconoscere il brano.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCoverSection() {
    if (isLoadingCover) {
      return Container(
        height: 230,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (coverUrl.isEmpty) {
      return Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade200,
              Colors.purple.shade100,
              Colors.blue.shade100,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.album_rounded, size: 64, color: Colors.white),
              SizedBox(height: 12),
              Text(
                'Copertina non trovata',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.network(
          coverUrl,
          height: 230,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              height: 230,
              color: Colors.black12,
              child: const Center(
                child: Text('Errore caricamento copertina'),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildStatChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6C4DFF)),
          const SizedBox(width: 8),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Color(0xFF24164C)),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildApiTokenCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API key riconoscimento',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF24164C),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inserisci la tua chiave AudD per far funzionare il tastino Trova musica.',
              style: TextStyle(
                color: Color(0xFF6D6487),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: apiTokenController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'AudD API key',
                prefixIcon: Icon(Icons.vpn_key_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await saveApiToken();
                  _showSnack('API key salvata');
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Salva API key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF24164C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRecognitionResultCard() {
    if (recognitionResult == null) return const SizedBox.shrink();

    final result = recognitionResult!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Brano riconosciuto',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF24164C),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title.isEmpty ? 'Titolo non disponibile' : result.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF24164C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.artist.isEmpty
                        ? 'Artista non disponibile'
                        : result.artist,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4B4268),
                    ),
                  ),
                  if (result.album.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Album: ${result.album}',
                      style: const TextStyle(color: Color(0xFF4B4268)),
                    ),
                  ],
                  if (result.timecode.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Punto riconosciuto: ${result.timecode}',
                      style: const TextStyle(color: Color(0xFF4B4268)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: openRecognitionBestLink,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Apri il brano trovato'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C4DFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildShazamCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modalità Trova musica',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF24164C),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Registra un breve clip audio e prova a riconoscere automaticamente il brano.',
              style: TextStyle(
                color: Color(0xFF6D6487),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF101828), Color(0xFF28314A)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Icon(
                    isRecording
                        ? Icons.graphic_eq_rounded
                        : isRecognizing
                            ? Icons.radar_rounded
                            : Icons.search_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRecording
                        ? 'Ascolto in corso: $recordingSecondsLeft s'
                        : isRecognizing
                            ? 'Riconoscimento in corso'
                            : 'Pronto a cercare il brano',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recognitionMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: (isRecording || isRecognizing)
                          ? null
                          : startShazamLikeRecording,
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('Trova musica'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F9D78),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: isRecording
                          ? () => stopShazamLikeRecording()
                          : (isRecognizing ? null : recognizeRecordedSong),
                      icon: Icon(
                        isRecording
                            ? Icons.stop_circle_outlined
                            : Icons.search_rounded,
                      ),
                      label: Text(isRecording ? 'Ferma' : 'Riconosci clip'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD8CCFF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (recordedFilePath.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Clip pronta: $recordedFilePath',
                  style: const TextStyle(color: Color(0xFF3F3563)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    recordingTimer?.cancel();
    recorder.dispose();
    titleController.dispose();
    artistController.dispose();
    lyricsController.dispose();
    linkController.dispose();
    apiTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Canzoni Emotive',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildGradientHeader(),
            const SizedBox(height: 18),
            buildApiTokenCard(),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analizza la tua canzone',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF24164C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Inserisci titolo, artista, testo e opzionalmente un link.',
                      style: TextStyle(color: Color(0xFF6D6487)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titolo canzone',
                        prefixIcon: Icon(Icons.music_note_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: artistController,
                      decoration: const InputDecoration(
                        labelText: 'Artista',
                        prefixIcon: Icon(Icons.mic_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lyricsController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Testo o pezzo del testo',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.lyrics_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: linkController,
                      decoration: const InputDecoration(
                        labelText: 'Link YouTube / Spotify opzionale',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C4DFF), Color(0xFF8B5CFF)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ElevatedButton(
                              onPressed: analyzeSong,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Analizza base',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton(
                              onPressed: clearFields,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFD8CCFF)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Pulisci',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: openSongLink,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Ascolta su YouTube'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D6D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: searchSongOnSpotify,
                        icon: const Icon(Icons.headphones_rounded),
                        label: const Text('Cerca su Spotify'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF24164C),
                          side: const BorderSide(color: Color(0xFFD8CCFF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            buildShazamCard(),
            const SizedBox(height: 18),
            buildRecognitionResultCard(),
            const SizedBox(height: 18),
            buildCoverSection(),
            const SizedBox(height: 18),
            if (emotion.isNotEmpty || description.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Risultato analisi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF24164C),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (emotion.isNotEmpty)
                            buildStatChip(
                              Icons.favorite_rounded,
                              'Emozione',
                              emotion,
                            ),
                          if (theme.isNotEmpty)
                            buildStatChip(
                              Icons.auto_awesome_rounded,
                              'Tema',
                              theme,
                            ),
                          if (atmosphere.isNotEmpty)
                            buildStatChip(
                              Icons.nights_stay_rounded,
                              'Atmosfera',
                              atmosphere,
                            ),
                        ],
                      ),
                      if (meaning.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F5FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Significato: $meaning',
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Color(0xFF24164C),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Descrizione della canzone',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF24164C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description.isEmpty
                            ? 'Premi il pulsante di analisi per generare la descrizione.'
                            : description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: Color(0xFF4B4268),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Storico analisi',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF24164C),
                          ),
                        ),
                        if (history.isNotEmpty)
                          TextButton(
                            onPressed: clearAllHistory,
                            child: const Text('Svuota'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (history.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text('Nessuna canzone analizzata ancora.'),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: history.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = history[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F5FF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              leading: item.coverUrl.isEmpty
                                  ? const CircleAvatar(
                                      backgroundColor: Color(0xFFE3DAFF),
                                      child: Icon(Icons.music_note_rounded),
                                    )
                                  : CircleAvatar(
                                      backgroundImage:
                                          NetworkImage(item.coverUrl),
                                    ),
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${item.artist} • ${item.emotion} • ${item.theme}',
                              ),
                              onTap: () => loadFromHistory(item),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete_outline_rounded),
                                onPressed: () => removeHistoryItem(index),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}