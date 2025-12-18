import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteHelper {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> loadModel() async {
    try {
      // Load labels
      final labelsData = await rootBundle.loadString('assets/model/labels.txt');
      _labels = labelsData
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            // Handle format: "0 Label Name" or "Label Name"
            final parts = line.trim().split(' ');
            if (parts.length > 1) {
              return parts.sublist(1).join(' ');
            }
            return line.trim();
          })
          .toList();

      // Load model
      final options = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset('assets/model/model_unquant.tflite',
          options: options);
      
      // Allocate tensors
      _interpreter!.allocateTensors();

      _isLoaded = true;
    } catch (e) {
      print('Error loading model: $e');
      _isLoaded = false;
      rethrow;
    }
  }

  List<Map<String, dynamic>>? predictImage(File imageFile) {
    if (_interpreter == null || !_isLoaded) {
      return null;
    }

    try {
      // Get input and output tensor details
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      final inputShape = inputTensor.shape;
      final outputShape = outputTensor.shape;
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];

      // Read and decode image
      final imageBytes = imageFile.readAsBytesSync();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        print('Error: Could not decode image.');
        return null;
      }

      // Crop the image to a square in the center
      final size = image.width < image.height ? image.width : image.height;
      final x = (image.width - size) ~/ 2;
      final y = (image.height - size) ~/ 2;
      final croppedImage = img.copyCrop(image, x: x, y: y, width: size, height: size);

      // Resize image to model's input dimensions
      final resizedImage = img.copyResize(croppedImage, width: inputWidth, height: inputHeight, interpolation: img.Interpolation.average);

      // Convert image to a 4D list of normalized pixel values
      final reshapedInput = _imageToInputTensor(resizedImage, inputHeight, inputWidth);
      
      // Prepare output buffer
      final outputBuffer = List.generate(outputShape[0], (i) => List<double>.filled(outputShape[1], 0.0));

      // Run inference
      _interpreter!.run(reshapedInput, outputBuffer);

      // Process output to get predictions with labels
      final predictions = <Map<String, dynamic>>[];
      final List<double> outputList = outputBuffer[0];
      for (int i = 0; i < outputList.length && i < _labels.length; i++) {
        predictions.add({
          'label': _labels[i],
          'confidence': outputList[i],
        });
      }

      // Sort by confidence (descending)
      predictions.sort((a, b) => 
          (b['confidence'] as double).compareTo(a['confidence'] as double));

      return predictions;
    } catch (e) {
      print('Error predicting image: $e');
      return null;
    }
  }

  List<List<List<List<double>>>> _imageToInputTensor(
      img.Image image, int inputSizeH, int inputSizeW) {
    final inputTensor = List.generate(
      1,
      (_) => List.generate(
        inputSizeH,
        (_) => List.generate(inputSizeW, (_) => List.filled(3, 0.0)),
      ),
    );

    for (int i = 0; i < inputSizeH; i++) {
      for (int j = 0; j < inputSizeW; j++) {
        final pixel = image.getPixel(j, i);
        // Normalize pixel values to [-1, 1] range for float models
        inputTensor[0][i][j][0] = (pixel.r - 127.5) / 127.5;
        inputTensor[0][i][j][1] = (pixel.g - 127.5) / 127.5;
        inputTensor[0][i][j][2] = (pixel.b - 127.5) / 127.5;
      }
    }
    return inputTensor;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}