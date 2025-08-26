import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:http/http.dart' as http;

import '../../constants/color.dart';

class PdfViewerPage extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerPage({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final _controller = PdfViewerController();

  Future<bool> _checkFileExists(String url) async {
    try {
      final response = await http
          .head(Uri.parse(url))
          .timeout(Duration(seconds: 8)); // 8초 제한
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkFileExists(widget.pdfUrl),
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final canOpen = snapshot.data == true && snapshot.hasError == false;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            centerTitle: true,
          ),
          body: Builder(builder: (_) {
            if (waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || snapshot.data == false) {
              return const Center(
                child: Text(
                  '파일을 열 수 없습니다.',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              );
            } else {
              return PdfViewer.uri(
                Uri.parse(widget.pdfUrl),
                controller: _controller,
                params: const PdfViewerParams(
                  textSelectionParams: PdfTextSelectionParams(
                    enabled: true,
                    enableSelectionHandles: true,
                    showContextMenuAutomatically: true,
                  ),
                ),
              );
            }
          }),
          bottomNavigationBar: waiting
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            canOpen ? '확인' : '닫기',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
