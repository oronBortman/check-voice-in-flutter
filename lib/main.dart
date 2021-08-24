import 'package:injectable/injectable.dart';
import 'package:porcupine/porcupine.dart';
import 'package:porcupine/porcupine_error.dart';
import 'package:porcupine/porcupine_manager.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:stacked/stacked.dart';

import 'package:flutter/material.dart';
var str="";

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  SpeechService s = new SpeechService();

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
            Text(
               "The waking key word" + str
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: s.initializeSpeechService,
        tooltip: 'Increment',
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

@singleton
class SpeechService with ReactiveServiceMixin {
  bool speechAvailable = false;
  stt.SpeechToText speech = stt.SpeechToText();
  late PorcupineManager porcupineManager;

  late Function(SpeechRecognitionResult result) contextCallback;

  /// Initialization function called when the app is first opened
  Future<void> initializeSpeechService() async {
    print("Procupine key words:");
    print(Porcupine.BUILT_IN_KEYWORDS);
    await createPorcupineManager();

    speechAvailable = await speech.initialize(
      onStatus: (status) {
        print('Speech to text status: ' + status);
      },
      onError: (errorNotification) {
        print('Speech to text error: ' + errorNotification.errorMsg);
      },
    );

    listenForWakeWord();
  }

  /// Start listening for user input
  /// resultCallback is optionally specified by the caller
  Future<void> startListening({required Function(SpeechRecognitionResult result) resultCallback}) async {
    if (speechAvailable) {
      await porcupineManager.stop();
      await speech.listen(
        partialResults: false,
        onResult: (result) async {
          print('Speech to text result: ' + result.recognizedWords);
          if (resultCallback != null) resultCallback(result); // Specified from caller
          if (contextCallback != null) contextCallback(result); // Set in SpeechService
          await porcupineManager.start();
          notifyListeners();
        },
      );
      notifyListeners();
    } else {
      print("The user has denied the use of speech recognition.");
    }
  }

  /// Stop listening to user input and free up the audio stream
  Future<void> stopListening() async {
    await speech.stop();
  }

  /// Create an instance of your porcupineManager which will listen for the given wake words
  /// Must call start on the manager to actually start listening
  Future<void> createPorcupineManager() async {
    try {
      porcupineManager = await PorcupineManager.fromKeywords(Porcupine.BUILT_IN_KEYWORDS, wakeWordCallback);
    } on PvError catch (err) {
      print("There is an error in Procupine:");
      print(err.message);
    }
  }

  /// The function that's triggered when the Porcupine instance recognizes a wake word
  /// Input is the index of the wake word in the list of those being used
  Future<void> wakeWordCallback(int word) async {
    print('Wake word index: ' + word.toString());
    str = "word.toString()";
    // Terminator - resets audio resources
    if (word == 13) {
      await disposeResources();
      await createPorcupineManager();
      listenForWakeWord();
    } else {
      await startListening(resultCallback: (SpeechRecognitionResult result) {  });
    }
  }

  /// Begin listening for a wake word
  void listenForWakeWord() async {
    try {
      await porcupineManager.start();
    } on PvAudioException catch (ex) {
      // deal with either audio exception
      print("There is an error:");
      print(ex.message);
    }
  }

  Future<void> disposeResources() async {
    porcupineManager.delete();
    await speech.cancel();
    await speech.stop();
  }
}