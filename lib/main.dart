
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const QuranApp());

const green = Color(0xFF124C3A);
const gold = Color(0xFFD5AE69);
const cream = Color(0xFFF8F5EC);

const api = 'https://api.alquran.cloud/v1';
const audioBase =
    'https://everyayah.com/data/Husary_128kbps/';

class Surah {
  final int number;
  final String name;
  final int count;

  Surah(this.number, this.name, this.count);

  factory Surah.fromJson(Map<String, dynamic> j) {
    return Surah(
      j['number'] as int,
      j['name'] as String,
      j['numberOfAyahs'] as int,
    );
  }
}

class Ayah {
  final int number;
  final String text;

  Ayah(this.number, this.text);

  factory Ayah.fromJson(Map<String, dynamic> j) {
    return Ayah(
      j['numberInSurah'] as int,
      j['text'] as String,
    );
  }
}

class QuizQuestion {
  final Ayah prompt;
  final Ayah answer;
  final List<Ayah> options;

  QuizQuestion(this.prompt, this.answer, this.options);
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'أكمل الآية',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const QuranHome(),
    );
  }
}

class QuranHome extends StatefulWidget {
  const QuranHome({super.key});

  @override
  State<QuranHome> createState() => _QuranHomeState();
}

class _QuranHomeState extends State<QuranHome> {
  List<Surah> surahs = [];
  List<Ayah> ayahs = [];
  List<QuizQuestion> quiz = [];

  int? selectedSurah;
  int questionCount = 5;
  int index = 0;
  int score = 0;
  int? selectedOption;

  bool loading = true;
  bool checked = false;
  bool finished = false;
  bool inQuiz = false;

  String? error;
  String audioStatus = '';
  html.AudioElement? player;
  int playbackId = 0;

  @override
  void initState() {
    super.initState();
    loadSurahs();
  }

  Future<Map<String, dynamic>> fetchJson(
      String url) async {
    final response =
        await html.HttpRequest.getString(url);
    final decoded = jsonDecode(response);
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> loadSurahs() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final json = await fetchJson('$api/surah');
      final data = json['data'] as List;

      if (!mounted) return;

      setState(() {
        surahs = data
            .map((e) => Surah.fromJson(
                Map<String, dynamic>.from(e)))
            .toList();
        selectedSurah = 112;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذر تحميل فهرس السور. '
            'تحققي من الإنترنت وحاولي مجددًا.';
      });
    }
  }

  Future<void> startQuiz() async {
    if (selectedSurah == null) return;

    stopAudio();

    setState(() {
      loading = true;
      error = null;
      inQuiz = false;
      finished = false;
    });

    try {
      final json = await fetchJson(
        '$api/surah/$selectedSurah/quran-uthmani',
      );

      final data = json['data'] as Map<String, dynamic>;
      final list = (data['ayahs'] as List)
          .map((e) => Ayah.fromJson(
              Map<String, dynamic>.from(e)))
          .toList();

      if (list.length < 3) {
        throw Exception('Not enough ayahs');
      }

      final random = Random();
      final positions = List<int>.generate(
        list.length - 1,
        (i) => i,
      )..shuffle(random);

      final chosen = positions
          .take(min(questionCount, positions.length))
          .toList();

      final generated = <QuizQuestion>[];

      for (final pos in chosen) {
        final correct = list[pos + 1];

        final distractors = list
            .where((a) => a.number != correct.number)
            .toList()
          ..shuffle(random);

        final options = <Ayah>[
          correct,
          ...distractors.take(2),
        ]..shuffle(random);

        generated.add(
          QuizQuestion(
            list[pos],
            correct,
            options,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        ayahs = list;
        quiz = generated;
        index = 0;
        score = 0;
        selectedOption = null;
        checked = false;
        finished = false;
        inQuiz = true;
        loading = false;
        audioStatus = 'اضغطي للاستماع إلى الآية';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'تعذر تحميل آيات السورة. '
            'حاولي مرة أخرى.';
      });
    }
  }

  String audioUrl(int ayah) {
    final surah =
        selectedSurah!.toString().padLeft(3, '0');
    final verse = ayah.toString().padLeft(3, '0');
    return '$audioBase$surah$verse.mp3';
  }

  void stopAudio() {
    playbackId++;
    player?.pause();
    player = null;
  }

  void playAyah(int ayahNumber) {
    stopAudio();

    final id = playbackId;
    final audio =
        html.AudioElement(audioUrl(ayahNumber));

    player = audio;

    setState(() {
      audioStatus = 'جاري تشغيل التلاوة...';
    });

    audio.onEnded.first.then((_) {
      if (!mounted || id != playbackId) return;
      setState(() {
        audioStatus = 'انتهت التلاوة';
      });
    });

    audio.onError.first.then((_) {
      if (!mounted || id != playbackId) return;
      setState(() {
        audioStatus = 'تعذر تحميل التسجيل الصوتي';
      });
    });

    audio.play().catchError((_) {
      if (!mounted || id != playbackId) return;
      setState(() {
        audioStatus =
            'اضغطي زر الاستماع لتشغيل الصوت';
      });
    });
  }

  void confirmAnswer() {
    if (selectedOption == null || checked) return;

    final q = quiz[index];
    final selectedAyah = q.options[selectedOption!];

    setState(() {
      checked = true;
      if (selectedAyah.number == q.answer.number) {
        score++;
      }
    });

    playAyah(q.answer.number);
  }

  void nextQuestion() {
    stopAudio();

    setState(() {
      if (index == quiz.length - 1) {
        finished = true;
      } else {
        index++;
        selectedOption = null;
        checked = false;
        audioStatus = 'اضغطي للاستماع إلى الآية';
      }
    });
  }

  void goHome() {
    stopAudio();
    setState(() {
      inQuiz = false;
      finished = false;
      checked = false;
      selectedOption = null;
      error = null;
    });
  }

  @override
  void dispose() {
    stopAudio();
    super.dispose();
  }

  Widget panel(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEAE0CD),
        ),
      ),
      child: child,
    );
  }

  Widget actionButton(
      String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17),
        ),
      ),
    );
  }

  Widget errorView() {
    return panel(
      Column(
        children: [
          const Icon(
            Icons.wifi_off,
            color: Colors.red,
            size: 40,
          ),
          const SizedBox(height: 15),
          Text(
            error!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          actionButton(
            'إعادة المحاولة',
            surahs.isEmpty ? loadSurahs : startQuiz,
          ),
          const SizedBox(height: 10),
          if (surahs.isNotEmpty)
            actionButton('العودة للرئيسية', goHome),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أكمل الآية'),
        centerTitle: true,
        backgroundColor: green,
        foregroundColor: Colors.white,
        leading: inQuiz
            ? IconButton(
                icon: const Icon(Icons.home),
                onPressed: goHome,
              )
            : const Icon(Icons.menu_book),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(45),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : error != null
                  ? errorView()
                  : !inQuiz
                      ? homeView()
                      : finished
                          ? resultView()
                          : quizView(),
        ),
      ),
    );
  }

  Widget homeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: green,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.auto_stories,
                size: 65,
                color: gold,
              ),
              SizedBox(height: 15),
              Text(
                'رحلتك مع القرآن الكريم',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'اختبر حفظك بصوت الشيخ الحصري',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        panel(
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اختر السورة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: green,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: selectedSurah,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: surahs.map((s) {
                  return DropdownMenuItem<int>(
                    value: s.number,
                    child: Text(
                      '${s.number} - ${s.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSurah = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'عدد الأسئلة',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [5, 10, 20].map((n) {
                  return ChoiceChip(
                    label: Text('$n'),
                    selected: questionCount == n,
                    onSelected: (_) {
                      setState(() {
                        questionCount = n;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 15),
              const Text(
                'السور القصيرة قد تحتوي على '
                'أسئلة أقل من العدد المختار.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              actionButton(
                'ابدأ الاختبار الصوتي',
                startQuiz,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'القرآن الكريم - 114 سورة\n'
          'التلاوة: محمود خليل الحصري',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            height: 1.8,
          ),
        ),
      ],
    );
  }

  Widget quizView() {
    final q = quiz[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'السؤال ${index + 1} من ${quiz.length}',
          style: const TextStyle(
            fontSize: 18,
            color: green,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: (index + 1) / quiz.length,
          minHeight: 8,
          color: green,
        ),
        const SizedBox(height: 20),
        panel(
          Column(
            children: [
              const Icon(
                Icons.menu_book,
                size: 42,
                color: gold,
              ),
              const SizedBox(height: 12),
              Text(
                surahs
                    .firstWhere(
                      (s) => s.number == selectedSurah,
                    )
                    .name,
                style: const TextStyle(
                  fontSize: 19,
                  color: green,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'الآية ${q.prompt.number}',
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                q.prompt.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  height: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '﴿ ........ ﴾',
                style: TextStyle(
                  fontSize: 27,
                  color: gold,
                ),
              ),
              const SizedBox(height: 18),
              actionButton(
                '🔊 استمع إلى القارئ',
                () => playAyah(q.prompt.number),
              ),
              const SizedBox(height: 10),
              Text(
                audioStatus,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'ما الآية التالية؟',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        ...List.generate(q.options.length, (i) {
          final option = q.options[i];
          final isSelected = selectedOption == i;
          final isCorrect =
              option.number == q.answer.number;

          Color bg = Colors.white;
          Color border = Colors.black12;

          if (checked && isCorrect) {
            bg = Colors.green.shade100;
            border = Colors.green;
          } else if (checked && isSelected) {
            bg = Colors.red.shade100;
            border = Colors.red;
          } else if (isSelected) {
            bg = const Color(0xFFE3EFE7);
            border = green;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: checked
                  ? null
                  : () {
                      setState(() {
                        selectedOption = i;
                      });
                    },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius:
                      BorderRadius.circular(14),
                  border: Border.all(
                    color: border,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  option.text,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.7,
                  ),
                ),
              ),
            ),
          );
        }),

        if (checked)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: panel(
              Column(
                children: [
                  Icon(
                    q.options[selectedOption!].number ==
                            q.answer.number
                        ? Icons.check_circle
                        : Icons.cancel,
                    size: 40,
                    color:
                        q.options[selectedOption!].number ==
                                q.answer.number
                            ? Colors.green
                            : Colors.red,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    q.options[selectedOption!].number ==
                            q.answer.number
                        ? 'أحسنت! إجابة صحيحة'
                        : 'إجابة غير صحيحة',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'الإجابة الصحيحة:\n${q.answer.text}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  actionButton(
                    '🔊 استمع إلى التكملة',
                    () => playAyah(q.answer.number),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 22),
        actionButton(
          checked
              ? index == quiz.length - 1
                  ? 'عرض النتيجة'
                  : 'السؤال التالي'
              : 'تأكيد الإجابة وسماع التكملة',
          checked
              ? nextQuestion
              : selectedOption == null
                  ? null
                  : confirmAnswer,
        ),
      ],
    );
  }

  Widget resultView() {
    final percent =
        (score / quiz.length * 100).round();

    return panel(
      Column(
        children: [
          const Icon(
            Icons.emoji_events,
            color: gold,
            size: 75,
          ),
          const SizedBox(height: 15),
          const Text(
            'اكتمل الاختبار!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 48,
              color: green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$score إجابات صحيحة من ${quiz.length}',
            style: const TextStyle(fontSize: 19),
          ),
          const SizedBox(height: 24),
          actionButton('إعادة الاختبار', startQuiz),
          const SizedBox(height: 12),
          actionButton('اختيار سورة أخرى', goHome),
        ],
      ),
    );
  }
}
