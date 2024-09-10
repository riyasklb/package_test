import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() {
  runApp(VideoWatermarkApp());
}

class VideoWatermarkApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VideoWatermarkHomePage(),
    );
  }
}

class VideoWatermarkHomePage extends StatefulWidget {
  @override
  _VideoWatermarkHomePageState createState() => _VideoWatermarkHomePageState();
}

class _VideoWatermarkHomePageState extends State<VideoWatermarkHomePage> {
  String? _videoPath;
  String? _imagePath;
  String? _outputPath;
  bool _isProcessing = false;
  VideoPlayerController? _pickedVideoController;
  VideoPlayerController? _processedVideoController;

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      print("Storage permission granted");
    } else {
      print("Storage permission denied");
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      final path = result.files.single.path;
      if (path != null) {
        setState(() {
          _videoPath = path;
          _pickedVideoController = VideoPlayerController.network(path)
            ..initialize().then((_) {
              setState(() {});
            }).catchError((error) {
              print("Error initializing video controller: $error");
            });
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _imagePath = result.files.single.path;
      });
    }
  }

  void checkPaths() {
    print('Video Path exists: ${File(_videoPath!).existsSync()}');
    print('Image Path exists: ${File(_imagePath!).existsSync()}');
    print('Output Path: $_outputPath');
  }

  Future<void> _addWatermarkToVideo() async {
    if (_videoPath == null || _imagePath == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final outputDirectory = Directory('/storage/emulated/0/Download'); // Saving to Download directory
      _outputPath = '${outputDirectory.path}/output.mp4';

      final command =
          '-i "${_videoPath!}" -i "${_imagePath!}" -filter_complex "overlay=10:10" "${_outputPath!}"';

      print('Running FFmpeg command: $command');

      await FFmpegKit.executeAsync(command, (session) async {
        final returnCode = await session.getReturnCode();
        final log = await session.getAllLogsAsString();
        checkPaths();

        if (ReturnCode.isSuccess(returnCode)) {
          _processedVideoController = VideoPlayerController.file(File(_outputPath!))
            ..initialize().then((_) {
              setState(() {
                _isProcessing = false;
              });
              _processedVideoController?.play(); // Autoplay processed video
            });
          print('Watermark added successfully: $_outputPath');
        } else {
          setState(() {
            _isProcessing = false;
          });
          print('Failed to add watermark. Log: $log');
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      print('Error occurred: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Watermark Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: _pickVideo,
                  child: Text('Pick Video'),
                ),
                if (_videoPath != null) ...[
                  SizedBox(height: 16),
                  Text('Picked Video:'),
                  _pickedVideoController != null &&
                          _pickedVideoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _pickedVideoController!.value.aspectRatio,
                          child: VideoPlayer(_pickedVideoController!),
                        )
                      : Container(
                          height: 200,
                          color: Colors.black,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                ],
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text('Pick Watermark Image'),
                ),
                if (_imagePath != null) Text('Image: $_imagePath'),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _addWatermarkToVideo,
                  child: _isProcessing
                      ? CircularProgressIndicator()
                      : Text('Add Watermark to Video'),
                ),
                if (_outputPath != null) ...[
                  SizedBox(height: 32),
                  Text('Output: $_outputPath'),
                  _processedVideoController != null &&
                          _processedVideoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _processedVideoController!.value.aspectRatio,
                          child: VideoPlayer(_processedVideoController!),
                        )
                      : Container(
                          height: 200,
                          color: Colors.black,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (_processedVideoController!.value.isPlaying) {
                          _processedVideoController!.pause();
                        } else {
                          _processedVideoController!.play();
                        }
                      });
                    },
                    child: Icon(
                      _processedVideoController != null &&
                              _processedVideoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pickedVideoController?.dispose();
    _processedVideoController?.dispose();
    super.dispose();
  }
}
