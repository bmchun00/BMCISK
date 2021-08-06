import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equalizer/equalizer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File, Platform;
import 'dart:ui';
import 'dart:ui' as ui;
import 'MarqueeWidget.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:image/image.dart' as img;
int testInd = 0;
int tmp = 0;
bool wdChanged = false;
AudioPlayer audioPlayer = AudioPlayer();
Color mainColor = Colors.white;



var chanList = ['Electronica', 'K-pop','【﻿ｖａｐｏｒｗａｖｅ】','Future Bass']; //추가 예정 lofi, future bass 등등
var myLastMessage = '';

void main() async{
  await JustAudioBackground.init(androidShowNotificationBadge: true);
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(InitApp());

}

class InitApp extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ISK',
      home: AudioServiceWidget(child: MyApp()),
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  State createState() => Init();
}
class Init extends State {
  @override
  void dispose() {
    Equalizer.release();
    super.dispose();
  }

  @override
  void initState(){
    super.initState();  // initState()를 사용할 때 반드시 사용해야 한다.
    getMusicData(currServer);
    Equalizer.init(0);
    Equalizer.setEnabled(true);
    WidgetsBinding.instance!.addObserver(windowSizeChanged());
    for(int i = 0; i<chanList.length;i++){
      f.collection('PROFILE').doc(chanList[i]).snapshots().listen((DocumentSnapshot ds) {
        Map<String, dynamic>? tmpMap = ds.data();
        String data;
        data = tmpMap!['msg'];
        setState(() {
          if(myLastMessage!=data && tmp++>chanList.length-1) {
            messages.add(data);
            msgChannel.add(chanList[i]);
            talker.add(false);
          }
        });
      });
    }

    audioPlayer.playerStateStream.listen((state) {
      switch(state.processingState){
        case ProcessingState.completed:
          isRefresh = true;
          setState(() {
            calMusic();
          });
          musicPlayWithSeek(musicURL, 0); //야매지만... 다음곡으로 넘어갈 때는 항상 0부터 시작하도록,,
          break;
      }
    });

    Timer.periodic(Duration(seconds: 1),(timer){
      if(wdChanged) {
        setState(() {
        });
        wdChanged = false;
      }
    });
  }

  final textController = TextEditingController();
  final f = FirebaseFirestore.instance;
  var messages = ['Hello, This is BMCISK.', 'You can talk to anonymous people here!','Try touching the album art🤑','You can navigate to the next channel via the Skip button.'];
  var msgChannel = ['','','',''];
  var talker = [false, false, false,false];
  var musicStop = Icons.stop;
  var musicStart = Icons.play_arrow;
  var curTU = Icons.favorite_border;
  var curMusic = Icons.play_arrow;
  var thumbsDownN = Icons.thumb_down_alt_outlined;
  var thumbsDownY = Icons.thumb_down_alt;
  int currServer = Random().nextInt(chanList.length);
  double top = 460;
  var nowMusic = ['','Loading','Isk','']; //0 for albumart, 1 for title, 2 for artist
  var musicURL;
  int rdu = 0;
  var musicData=[];
  Duration? musicTime;
  double progress=0;
  bool isRefresh = false;
  bool isStop = true;
  bool isDarkMode = false;
  bool initSeekBar = false;
  final _controller = ScrollController();
  Widget SeekBar(double maxWidth, double maxHeight){
    return StatefulBuilder(builder: (_context,_setState){
      if(!initSeekBar){
        initSeekBar = true;
        Timer.periodic(Duration(seconds: 1),(timer){
          if(audioPlayer.position!=null && musicTime!=null) {
            _setState(() {
              double nValue = (1 - (musicTime!.inMilliseconds -
                  audioPlayer.position.inMilliseconds) /
                  (musicTime!.inMilliseconds)) * 100;
              progress = nValue > 100 ? 100 : nValue;
            });
          }
        });
      }
      return Container(
          height: 1.5,
          width: (maxWidth>maxHeight?maxHeight:maxWidth)*0.8,
          color: isDarkMode?Colors.grey:Colors.white,
          child:Row(
              children: [AnimatedContainer(
                height: 1.5,
                width: progress*((maxWidth>maxHeight?maxHeight:maxWidth)*0.8)/100,
                duration: Duration(milliseconds: 400),
                color: isDarkMode?Colors.white:Colors.black,
              ),]
          )
      );
    });
  }
  Future<void> getDominantColor(String path) async {
    final http.Response responseData = await http.get(Uri.parse(path));
    var uint8list = responseData.bodyBytes;
    var buffer = uint8list.buffer;
    ByteData byteData = ByteData.view(buffer);
    var tempDir = await getTemporaryDirectory();
    File tempFile = await File('${tempDir.path}/img');
    File file = await File('${tempDir.path}/img').writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    img.Image? bitmap =
    img.decodeImage(tempFile.readAsBytesSync());

    int redBucket = 0;
    int greenBucket = 0;
    int blueBucket = 0;
    int pixelCount = 0;

    for (int y = 0; y < bitmap!.height; y++) {
      for (int x = 0; x < bitmap.width; x++) {
        int c = bitmap.getPixel(x, y);

        pixelCount++;
        redBucket += img.getRed(c);
        greenBucket += img.getGreen(c);
        blueBucket += img.getBlue(c);
      }
    }

    mainColor = Color.fromRGBO(redBucket ~/ pixelCount,
        greenBucket ~/ pixelCount, blueBucket ~/ pixelCount, 1);
  }
  static Future<ui.Image> bytesToImage(Uint8List imgBytes) async{
    ui.Codec codec = await ui.instantiateImageCodec(imgBytes);
    ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }
  Future<void> setBackGroundColorByImage (String path) async {
    http.Response response = await http.get(
      Uri.parse(path),
    );
    Uint8List lst = response.bodyBytes;
    Image.memory(lst);
    var img = await bytesToImage(lst);
    var paletteGenerator = await PaletteGenerator.fromImage(
      img
    );
    print(paletteGenerator.dominantColor);
    setState(() {
      mainColor = paletteGenerator.dominantColor!.color.withOpacity(0.3);
      print(mainColor);
    });
  }
  musicPlayWithSeek(String url, seekTime) async {
    try{
      musicTime = await audioPlayer.setAudioSource(ClippingAudioSource(
        child: AudioSource.uri(Uri.parse(url)),
        tag: MediaItem(
          id: '0',
          artist: nowMusic[2],
          title: nowMusic[1],
          artUri: Uri.parse(nowMusic[0]),
        ),
      ),initialPosition: Duration(milliseconds: seekTime));
    }catch(e){ //이유를 알 수 없지만 웹에서는 작동을 안함. 어차피 할 필요도 없긴 함.
      musicTime = await audioPlayer.setUrl(url);
      audioPlayer.seek(Duration(milliseconds: seekTime));
    }
    audioPlayer.play();
  }
  Future<void> getMusicData(int index) async { //나중에 서버쪽으로 이관
    var uri = 'https://bmchun00.github.io/assets/musicDataS'+(index+1).toString()+'.json';
    var response = await http.get(Uri.parse(uri));
    print("getMusicData");
    var dcd = json.decode(response.body);
    for(int i = 0;i<dcd.length;i++){
      musicData.add([i,dcd[i]['art'],dcd[i]['title'],dcd[i]['artist'],dcd[i]['mp3'],int.parse(dcd[i]['duration'])]);
    }
    setState(() {
      calMusic();
    });
  }
  Future<void> nextServer() async {
    bool whilePlaying = curMusic==musicStop;
    musicStopF();
    musicData = [];
    currServer = (currServer+1)%4;
    await getMusicData(currServer);
    if(whilePlaying)
      musicStartF();
    setState(() {
    });

  }
  int calMusic() {
    var now = DateTime.now();
    int allMusicTime =0;
    int curMusicTime;
    int musicIndex=0;
    for(int i = 0; i<musicData.length;i++){
      allMusicTime += (musicData[i][5] as int);
    }
    curMusicTime = (now.millisecondsSinceEpoch)%allMusicTime;
    for(int i = 0;i<musicData.length;i++){
      if((curMusicTime<(musicData[i][5] as int))) {
        musicIndex = i;
        break;
      }else{
        curMusicTime-=(musicData[i][5] as int);
      }
    }
    nowMusic[0] = musicData[musicIndex][1] as String;
    nowMusic[1] = musicData[musicIndex][2] as String;
    nowMusic[2] = musicData[musicIndex][3] as String;
    musicURL = musicData[musicIndex][4] as String;
    setBackGroundColorByImage(nowMusic[0]);
    return curMusicTime;
  }

  void musicStartF(){
    isStop = false;
    int duration = calMusic();
    musicPlayWithSeek(musicURL,duration);
    curMusic = musicStop;
  }
  AlertDialog eqPopUp(){
    return AlertDialog(
      title: Text('Equalizer'),
      content: SingleChildScrollView(
        child: FutureBuilder<List<int>>(
          future: Equalizer.getBandLevelRange(),
          builder: (context, snapshot) {
            print(snapshot.data);
            return snapshot.connectionState == ConnectionState.done
                ? CustomEQ(true,[-15, 15] )
                : CircularProgressIndicator();
          },
        ),
      ),
    );
  }
  void musicStopF(){
    isStop = true;
    audioPlayer.pause();
    curMusic = musicStart;
  }

  void addMyMessage(String str){
    setState(() {
      messages.add(str);
      msgChannel.add(chanList[currServer]);
      talker.add(true);
    });
  }
  void addSomeMessage(String str){
    setState(() {
      messages.add(str);
      msgChannel.add(chanList[currServer]);
      talker.add(false);
    });
  }
  Widget build(BuildContext context) {
    double maxWidth = (window.physicalSize.width / window.devicePixelRatio * 1.35> window.physicalSize.height / window.devicePixelRatio)? window.physicalSize.height / window.devicePixelRatio / 2: window.physicalSize.width / window.devicePixelRatio;
    double maxHeight = window.physicalSize.height / window.devicePixelRatio;
    double stdSize = (maxWidth>maxHeight?maxHeight:maxWidth);
    bool isLandScape = (window.physicalSize.width / window.devicePixelRatio * 1.35> window.physicalSize.height / window.devicePixelRatio);
    return MaterialApp(
      home:Scaffold(
        body: Stack( children:[AnimatedContainer(
          color: isDarkMode?Colors.grey.shade900:Colors.grey.shade100,
          child: AnimatedContainer(
            color: isDarkMode?mainColor:Colors.white,
            duration: Duration(seconds:1),
            child: CustomScrollView(
                controller: _controller,
                slivers: <Widget>[
                  SliverAppBar( // <-- app bar for logo
                      expandedHeight: maxHeight,
                      toolbarHeight: maxHeight/6,
                      floating: true,
                      pinned: true,
                      snap: false,
                      elevation: 0.0,
                      flexibleSpace: LayoutBuilder(
                          builder:(BuildContext context, BoxConstraints constraints){
                            top = constraints.biggest.height;
                            return AnimatedContainer(
                                duration: Duration(seconds: 1),
                                color: isDarkMode?Colors.grey.shade900:Colors.grey.shade100,
                                child: AnimatedContainer(
                                  duration: Duration(seconds: 1),
                                  color: mainColor,
                                  child: SafeArea(child: FlexibleSpaceBar(
                                    centerTitle: true,
                                    title:
                                    AnimatedOpacity(opacity: top <= maxHeight/6+MediaQuery.of(context).padding.top ? 1.0 : 0.0, duration: Duration(milliseconds: 100),
                                        child:Container(
                                            margin: EdgeInsets.fromLTRB(isLandScape?(window.physicalSize.width / window.devicePixelRatio)/2-maxWidth*0.4:maxWidth*0.1,maxHeight/6*0.15,isLandScape?(window.physicalSize.width / window.devicePixelRatio)/2-maxWidth*0.4:maxWidth*0.1,0),
                                            child:Column(
                                              children: [Container(
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: maxHeight/6*0.7,
                                                      height: maxHeight/6*0.7,
                                                      child:FlatButton(onPressed: (){
                                                        setState(() {
                                                          rdu=(rdu+1)%3;
                                                        });
                                                      },
                                                        padding: EdgeInsets.zero,
                                                        child:AnimatedContainer(
                                                          width: maxHeight/6*0.7,
                                                          height: maxHeight/6*0.7,
                                                          duration: Duration(milliseconds: 300),
                                                          decoration: BoxDecoration(
                                                            borderRadius: BorderRadius.circular(rdu*maxHeight/6*0.7/4),
                                                            image: nowMusic[0]!=null?(DecorationImage(
                                                                image: NetworkImage(nowMusic[0]),
                                                                fit:BoxFit.cover
                                                            )):null,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: maxHeight/6*0.15,),
                                                    Flexible(
                                                        child:
                                                        Column(
                                                          children: [Center(
                                                            child: SizedBox(
                                                                width: double.infinity,
                                                                child: MarqueeWidget(
                                                                  direction: Axis.horizontal,
                                                                  child: Text(
                                                                    nowMusic[1],
                                                                    style: TextStyle(
                                                                      fontSize: maxHeight/45,
                                                                      color: isDarkMode?Colors.white:Colors.black,
                                                                      fontWeight: FontWeight.w300,
                                                                    ),
                                                                  ),
                                                                )
                                                            ),
                                                          ),
                                                            Center(
                                                              child: SizedBox(
                                                                  width: double.infinity,
                                                                  child: MarqueeWidget(
                                                                    direction: Axis.horizontal,
                                                                    child: Text(
                                                                      nowMusic[2],
                                                                      style: TextStyle(
                                                                          fontSize: maxHeight/55,
                                                                          color: isDarkMode?Colors.grey.shade400:Colors.grey.shade700,
                                                                          fontWeight: FontWeight.w300
                                                                      ),
                                                                    ),
                                                                  )
                                                              ),
                                                            ),
                                                            SizedBox(height: 10,),

                                                            Row(
                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                              children: [
                                                                ClipRRect(
                                                                  borderRadius: BorderRadius.circular(50),
                                                                  child : Material(
                                                                    color: Colors.transparent,
                                                                    child : InkWell(
                                                                      child : Padding(
                                                                        padding : const EdgeInsets.all(1),
                                                                        child : Icon(
                                                                          isDarkMode?Icons.wb_sunny_outlined:Icons.wb_sunny,
                                                                          size: maxWidth/20,
                                                                          color: isDarkMode?Colors.white:Colors.black,
                                                                        ),
                                                                      ),
                                                                      onTap : () {
                                                                        setState(() {
                                                                          isDarkMode = !isDarkMode;
                                                                        });
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                                ClipRRect(
                                                                  borderRadius: BorderRadius.circular(50),
                                                                  child : Material(
                                                                    color: Colors.transparent,
                                                                    child : InkWell(
                                                                      child : Padding(
                                                                        padding : EdgeInsets.all(1),
                                                                        child : Icon(
                                                                          Icons.graphic_eq_rounded,
                                                                          size: maxWidth/20,
                                                                          color: isDarkMode?Colors.white:Colors.black,
                                                                        ),
                                                                      ),
                                                                      onTap : () {
                                                                        try {
                                                                          if (Platform.isAndroid) {
                                                                            showDialog(
                                                                                context: context,
                                                                                builder: (context) {
                                                                                  return StatefulBuilder(
                                                                                      builder: (context,
                                                                                          setState) {
                                                                                        return eqPopUp();
                                                                                      });
                                                                                });
                                                                          }else{
                                                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                                              content: Text("only support Android for now."),
                                                                            ));
                                                                          }
                                                                        }catch(e){
                                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                                            content: Text("only support Android for now."),
                                                                          ));
                                                                        }
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                                ClipRRect(
                                                                  borderRadius: BorderRadius.circular(50),
                                                                  child : Material(
                                                                    color: Colors.grey.withOpacity(0.6),
                                                                    child : InkWell(
                                                                      child : Padding(
                                                                        padding : const EdgeInsets.all(5),
                                                                        child : Icon(
                                                                          curMusic,
                                                                          size: maxWidth/20,
                                                                          color: isDarkMode?Colors.white:Colors.black,
                                                                        ),
                                                                      ),
                                                                      onTap : () {
                                                                        setState(() {
                                                                          if(curMusic!=musicStop)
                                                                            musicStartF();
                                                                          else
                                                                            musicStopF();
                                                                        });
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                                ClipRRect(
                                                                  borderRadius: BorderRadius.circular(50),
                                                                  child : Material(
                                                                    color: Colors.transparent,
                                                                    child : InkWell(
                                                                      child : Padding(
                                                                        padding : const EdgeInsets.all(1),
                                                                        child : Icon(
                                                                          curTU,
                                                                          size: maxWidth/20,
                                                                          color: isDarkMode?Colors.white:Colors.black,
                                                                        ),
                                                                      ),
                                                                      onTap : () {
                                                                        setState(() {
                                                                          rdu = 1;
                                                                        });
                                                                        curTU = (curTU==Icons.favorite_border?Icons.favorite:Icons.favorite_border);
                                                                        addSomeMessage("상대 테스트 메시지");
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                                ClipRRect(
                                                                  borderRadius: BorderRadius.circular(50),
                                                                  child : Material(
                                                                    color: Colors.transparent,
                                                                    child : InkWell(
                                                                      child : Padding(
                                                                        padding : EdgeInsets.all(1),
                                                                        child : Icon(
                                                                          Icons.skip_next_rounded,
                                                                          size: maxWidth/20,
                                                                          color: isDarkMode?Colors.white:Colors.black,
                                                                        ),
                                                                      ),
                                                                      onTap : () {
                                                                        nextServer();
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        )
                                                    )],
                                                ),
                                              ),
                                              ],
                                            )
                                        )
                                    ),
                                    background:Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        DottedBorder(
                                          borderType: BorderType.RRect,
                                          color: isDarkMode?Colors.white:Colors.black,
                                          strokeWidth: 0.7,
                                          radius: Radius.circular(100),
                                          padding: EdgeInsets.fromLTRB(10,2,10,2),
                                          child: Text(chanList[currServer],
                                            style: TextStyle(
                                              fontSize: maxHeight/50,
                                              color: isDarkMode?Colors.white:Colors.black,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          height: maxHeight/40,
                                        ),
                                        FlatButton(onPressed: (){
                                          setState(() {
                                            rdu=(rdu+1)%3;
                                          });
                                        }, child: AnimatedContainer(
                                          width: (maxWidth>maxHeight?maxHeight:maxWidth)*0.8,
                                          height: (maxWidth>maxHeight?maxHeight:maxWidth)*0.8,
                                          decoration: BoxDecoration(
                                            image: nowMusic[0]!=null?(DecorationImage(
                                                image: NetworkImage(nowMusic[0]),
                                                fit:BoxFit.cover
                                            )):null,
                                            borderRadius: BorderRadius.circular(rdu*((stdSize*0.8)/4)),
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: isDarkMode?Colors.black:Colors.grey.withOpacity(0.5),
                                                spreadRadius: 0,
                                                blurRadius: 1,
                                                offset: Offset(-6, 6), // changes position of shadow
                                              ),
                                            ],
                                          ), duration: Duration(milliseconds: 300),
                                        ),
                                        ),
                                        SizedBox(
                                          height: maxHeight/30,
                                        ),
                                        Center(
                                          child: SizedBox(
                                              width: maxWidth*0.8,
                                              child: MarqueeWidget(
                                                direction: Axis.horizontal,
                                                child: Text(
                                                  nowMusic[1],
                                                  style: TextStyle(
                                                    fontSize: maxHeight/30,
                                                    color: isDarkMode?Colors.white:Colors.black,
                                                    fontWeight: FontWeight.w300,
                                                  ),
                                                ),
                                              )
                                          ),
                                        ),
                                        Center(
                                          child: SizedBox(
                                              width: maxWidth*0.8,
                                              child: MarqueeWidget(
                                                direction: Axis.horizontal,
                                                child: Text(
                                                  nowMusic[2],
                                                  style: TextStyle(
                                                      fontSize: maxHeight/45,
                                                      color: isDarkMode?Colors.grey.shade400:Colors.grey.shade700,
                                                      fontWeight: FontWeight.w300
                                                  ),
                                                ),
                                              )
                                          ),
                                        ),
                                        SizedBox(
                                          height: maxHeight/30,
                                        ),
                                        SeekBar(maxWidth,maxHeight),
                                        SizedBox(
                                          height: maxHeight/30,
                                        ),
                                        Container(width: maxWidth*0.8,child:Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(100),
                                              child : Material(
                                                color: Colors.transparent,
                                                child : InkWell(
                                                  child : Padding(
                                                    padding : EdgeInsets.all((stdSize/50)),
                                                    child : Icon(
                                                      isDarkMode?Icons.wb_sunny_outlined:Icons.wb_sunny,
                                                      size: stdSize/15,
                                                      color: isDarkMode?Colors.white:Colors.black,
                                                    ),
                                                  ),
                                                  onTap : () {
                                                    setState(() {
                                                      isDarkMode = !isDarkMode;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(100),
                                              child : Material(
                                                color: Colors.transparent,
                                                child : InkWell(
                                                  child : Padding(
                                                    padding : EdgeInsets.all((stdSize/50)),
                                                    child : Icon(
                                                      Icons.graphic_eq_rounded,
                                                      size: stdSize/15,
                                                      color: isDarkMode?Colors.white:Colors.black,
                                                    ),
                                                  ),
                                                  onTap : () {
                                                    try {
                                                      if (Platform.isAndroid) {
                                                        showDialog(
                                                            context: context,
                                                            builder: (context) {
                                                              return StatefulBuilder(
                                                                  builder: (context,
                                                                      setState) {
                                                                    return eqPopUp();
                                                                  });
                                                            });
                                                      }else{
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                          content: Text("only support Android for now."),
                                                        ));
                                                      }
                                                    }catch(e){
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                        content: Text("only support Android for now."),
                                                      ));
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                            DottedBorder(
                                              dashPattern: [3,2],
                                              borderType: BorderType.RRect,
                                              radius: Radius.circular(100),
                                              strokeWidth: 0.7,
                                              color: isDarkMode?Colors.white:Colors.black,
                                              child : InkWell(
                                                child : Padding(
                                                  padding :EdgeInsets.all((stdSize/40)),
                                                  child : Icon(
                                                    curMusic,
                                                    size:stdSize/13,
                                                    color: isDarkMode?Colors.white:Colors.black,
                                                  ),
                                                ),
                                                onTap : () {
                                                  setState(() {
                                                    if(curMusic!=musicStop)
                                                      musicStartF();
                                                    else
                                                      musicStopF();
                                                  });
                                                },
                                              ),
                                            ),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(100),
                                              child : Material(
                                                color: Colors.transparent,
                                                child : InkWell(
                                                  child : Padding(
                                                    padding : EdgeInsets.all((stdSize/50)),
                                                    child : Icon(
                                                      curTU,
                                                      size: stdSize/15,
                                                      color: isDarkMode?Colors.white:Colors.black,
                                                    ),
                                                  ),
                                                  onTap : () {
                                                    curTU = (curTU==Icons.favorite_border?Icons.favorite:Icons.favorite_border);
                                                    addSomeMessage("상대 테스트 메시지");
                                                  },
                                                ),
                                              ),
                                            ),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(100),
                                              child : Material(
                                                color: Colors.transparent,
                                                child : InkWell(
                                                  child : Padding(
                                                    padding : EdgeInsets.all((stdSize/50)),
                                                    child : Icon(
                                                      Icons.skip_next_rounded,
                                                      size: stdSize/15,
                                                      color: isDarkMode?Colors.white:Colors.black,
                                                    ),
                                                  ),
                                                  onTap : () {
                                                    nextServer();
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),),

                                        SizedBox(
                                          height: maxHeight/20,
                                        ),
                                        Icon(Icons.arrow_drop_up,size: stdSize/15,color: isDarkMode?Colors.white:Colors.black),

                                      ],
                                    ),
                                  ),
                                  ),
                                )
                            );
                          }
                      )
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(isLandScape?(window.physicalSize.width / window.devicePixelRatio)/2-maxWidth*0.4:maxWidth*0.1, maxHeight/60, isLandScape?(window.physicalSize.width / window.devicePixelRatio)/2-maxWidth*0.4:maxWidth*0.1, 15),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                          return AnimatedContainer(
                            child: Column(children: [
                              Row(
                                  mainAxisAlignment: talker[index]? MainAxisAlignment.end : MainAxisAlignment.start,
                                  children:[
                                    Flexible(
                                      child:
                                      AnimatedContainer(
                                        child:Text(msgChannel[index]==''?'Server Message':msgChannel[index],
                                          style: TextStyle(
                                              fontSize: maxHeight/70,
                                              color: isDarkMode?Colors.grey.shade300:Colors.grey.shade600,
                                              fontWeight: FontWeight.w300
                                          ),
                                        ),
                                        duration: Duration(seconds: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                  ]
                              ),
                              SizedBox(height: maxHeight/300,),
                              Row(
                                  mainAxisAlignment: talker[index]? MainAxisAlignment.end : MainAxisAlignment.start,
                                  children:[
                                    Flexible(
                                      child:
                                      AnimatedContainer(
                                        child:Text(messages[index],
                                          style: TextStyle(
                                              fontSize: maxHeight/60,
                                              color: isDarkMode?Colors.white:Colors.black,
                                              fontWeight: FontWeight.w300
                                          ),
                                        ),
                                        padding: EdgeInsets.all(maxHeight/200),
                                        margin: EdgeInsets.fromLTRB(0, 0, 0, maxHeight/60),
                                        duration: Duration(seconds: 1),
                                        decoration: BoxDecoration(
                                          color: talker[index]?(Colors.redAccent.withOpacity(0.2)):(isDarkMode?Colors.white.withOpacity(0.1):Colors.grey.withOpacity(0.1)),
                                          borderRadius: BorderRadius.circular(rdu*7.0),
                                        ),
                                      ),
                                    ),
                                  ]
                              ),
                            ],),
                            duration: Duration(seconds:1),
                          );
                        },
                        childCount: messages.length,
                      ),
                    ),
                  )
                  ,
                ]
            ),
          ),
          duration: Duration(seconds:1),
        ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
            color: Colors.transparent,
            duration: Duration(seconds:1),
            height: maxHeight/20,
            width: maxWidth*0.8,
            margin: EdgeInsets.fromLTRB(0, 0, 0, 5),
            child:
            TextField(
              controller: textController,
              style: TextStyle(fontSize: stdSize/30, color: isDarkMode?Colors.white:Colors.black,
                  fontWeight: FontWeight.w300),
              textAlign: TextAlign.left,
              decoration: InputDecoration(
                hintText: 'Input Message',
                hintStyle: TextStyle(
                    fontSize: stdSize/30, color: isDarkMode?Colors.grey.shade50:Colors.grey.shade800,
                    fontWeight: FontWeight.w300
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDarkMode?Colors.grey.shade50:Colors.grey.shade800, width: 1),
                ),
              ),
              onSubmitted: (value)async{
                myLastMessage = value;
                await f.collection('PROFILE').doc(chanList[currServer].toString()).update({'msg':value});
                addMyMessage(value);
                textController.text='';
                print(_controller.position.maxScrollExtent);
                _controller.animateTo(
                    _controller.position.maxScrollExtent+50, //수정필요
                    duration: Duration(milliseconds: 200),
                    curve: Curves.easeInOut
                );
              },
            ),
          ),
          )
        ]
        )
      ),
    );
  }
}

class windowSizeChanged with WidgetsBindingObserver {
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    print('값변함');
    wdChanged = true;
  }
}

class CustomEQ extends StatefulWidget {
  const CustomEQ(this.enabled, this.bandLevelRange);

  final bool enabled;
  final List<int> bandLevelRange;

  @override
  _CustomEQState createState() => _CustomEQState();
}
class _CustomEQState extends State<CustomEQ> {
  double? min, max;
  String? _selectedValue;
  Future<List<String>>? fetchPresets;

  @override
  void initState() {
    super.initState();
    min = widget.bandLevelRange[0].toDouble();
    max = widget.bandLevelRange[1].toDouble();
    fetchPresets = Equalizer.getPresetNames();
  }

  @override
  Widget build(BuildContext context) {
    int bandId = 0;

    return FutureBuilder<List<int>>(
      future: Equalizer.getCenterBandFreqs(),
      builder: (context, snapshot) {
        return snapshot.connectionState == ConnectionState.done
            ? Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: snapshot.data
                  !.map((freq) => _buildSliderBand(freq, bandId++))
                  .toList(),
            ),
            Divider(),
            _buildPresets(),
          ],
        )
            : CircularProgressIndicator(
        );
      },
    );
  }
  Widget _buildSliderBand(int freq, int bandId) {
    return Column(
      children: [
        SizedBox(
          height: 150.0,
          width: 20,
          child: FutureBuilder<int>(
            future: Equalizer.getBandLevel(bandId),
            builder: (context, snapshot) {
              return FlutterSlider(
                disabled: !widget.enabled,
                axis: Axis.vertical,
                rtl: true,
                min: min,
                max: max,
                values: [snapshot.hasData ? snapshot.data!.toDouble() : 0],
                onDragCompleted: (handlerIndex, lowerValue, upperValue) {
                  Equalizer.setBandLevel(bandId, lowerValue.toInt());
                },
                trackBar: FlutterSliderTrackBar(
                  inactiveTrackBar: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                  ),
                  activeTrackBar: BoxDecoration(
                      color: Colors.black
                  ),
                ),
                handler: FlutterSliderHandler(
                  decoration: BoxDecoration(),
                  child: Material(
                    type: MaterialType.canvas,
                    color: Colors.white,
                    elevation: 5,
                  ),
                ),
              );
            },
          ),
        ),
        Text((freq ~/ 1000)>1000? '${freq ~/ 1000000}'+'KHz':'${freq ~/ 1000}'+'Hz',style: TextStyle(
          fontSize: 10
        ),),
      ],
    );
  }

  Widget _buildPresets() {
    return FutureBuilder<List<String>>(
      future: fetchPresets,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final presets = snapshot.data;
          if (presets!.isEmpty) return Text('No presets available!');
          return DropdownButtonFormField(
            decoration: InputDecoration(
              labelText: 'Available Presets',
            ),
            value: _selectedValue,
            onChanged: widget.enabled
                ? (String? value) {
              Equalizer.setPreset(value);
              setState(() {
                _selectedValue = value!;
              });
            }
                : null,
            items: presets.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          );
        } else if (snapshot.hasError)
          return Text('error');
        else
          return CircularProgressIndicator();
      },
    );
  }
}
