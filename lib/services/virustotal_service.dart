import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class VTScanResult {
  final bool passed;
  final bool isError;
  final String title;
  final String summary;
  final Map<String, String> detections;

  const VTScanResult({
    required this.passed,
    this.isError = false,
    required this.title,
    required this.summary,
    this.detections = const {},
  });

  factory VTScanResult.clean() => const VTScanResult(
        passed: true,
        title: 'Scan Clean',
        summary: 'No security vendors flagged this APK as malicious.',
      );

  factory VTScanResult.error(String msg) => VTScanResult(
        passed: false,
        isError: true,
        title: 'VirusTotal Error',
        summary: msg,
      );
}

class VirusTotalService {
  static const String _baseUrl = 'https://www.virustotal.com/api/v3';

  static Future<VTScanResult> scanApk(String apkFilePath, String apiKey) async {
    if (apiKey.trim().isEmpty) {
      return VTScanResult.error('No VirusTotal API Key provided in Settings.');
    }

    final file = File(apkFilePath);
    if (!await file.exists()) {
      return VTScanResult.error('Target APK file could not be read from disk.');
    }

    try {
      // ─── TIER 1: FAST HASH LOOKUP (0.4 SECONDS) ───────────────────────
      final bytes = await file.readAsBytes();
      final fileHash = sha256.convert(bytes).toString();

      final headers = {'x-apikey': apiKey.trim()};
      final hashUrl = Uri.parse('$_baseUrl/files/$fileHash');
      
      var response = await http.get(hashUrl, headers: headers);

      if (response.statusCode == 200) {
        return _parseVerdict(jsonDecode(response.body));
      } else if (response.statusCode != 404) {
        return _handleApiError(response.statusCode, response.body);
      }

      // ─── TIER 2: FILE UPLOAD & ANALYSIS POLLING ───────────────────────
      final uploadUrl = Uri.parse('$_baseUrl/files');
      final request = http.MultipartRequest('POST', uploadUrl)
        ..headers.addAll(headers)
        ..files.add(await http.MultipartFile.fromPath('file', apkFilePath));

      final streamedResponse = await request.send();
      response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        return _handleApiError(response.statusCode, response.body);
      }

      final uploadData = jsonDecode(response.body);
      final analysisId = uploadData['data']?['id'];
      if (analysisId == null) {
        return VTScanResult.error('VirusTotal did not return a valid Analysis ID.');
      }

      // Poll analysis endpoint every 5 seconds (Max 24 attempts = 2 mins)
      final analysisUrl = Uri.parse('$_baseUrl/analyses/$analysisId');
      for (int attempt = 0; attempt < 24; attempt++) {
        await Future.delayed(const Duration(seconds: 5));
        final pollResp = await http.get(analysisUrl, headers: headers);
        
        if (pollResp.statusCode == 200) {
          final pollData = jsonDecode(pollResp.body);
          final status = pollData['data']?['attributes']?['status'];
          
          if (status == 'completed') {
            return _parseVerdict(pollData);
          }
        }
      }

      return VTScanResult.error('VirusTotal analysis timed out after 2 minutes.');
    } catch (e) {
      return VTScanResult.error('Network exception during scan: ${e.toString()}');
    }
  }

  static VTScanResult _parseVerdict(Map<String, dynamic> json) {
    final attributes = json['data']?['attributes'];
    final stats = attributes?['last_analysis_stats'] ?? attributes?['stats'];
    final results = attributes?['last_analysis_results'] ?? attributes?['results'];

    if (stats == null) {
      return VTScanResult.error('Malformed response received from VirusTotal API.');
    }

    final maliciousCount = (stats['malicious'] ?? 0) as int;
    final suspiciousCount = (stats['suspicious'] ?? 0) as int;

    if (maliciousCount == 0 && suspiciousCount == 0) {
      return VTScanResult.clean();
    }

    final Map<String, String> flaggedVendors = {};
    if (results is Map) {
      results.forEach((vendor, data) {
        final category = data['category'];
        if (category == 'malicious' || category == 'suspicious') {
          final resultName = data['result'] ?? 'Flagged as $category';
          flaggedVendors[vendor.toString()] = resultName.toString();
        }
      });
    }

    return VTScanResult(
      passed: false,
      isError: false,
      title: 'Security Threat Detected!',
      summary: '$maliciousCount security vendors flagged this application as malicious.',
      detections: flaggedVendors,
    );
  }

  static VTScanResult _handleApiError(int code, String body) {
    if (code == 401 || code == 403) {
      return VTScanResult.error('Authentication Failed: Your VirusTotal API Key is invalid or expired.');
    } if (code == 429) {
      return VTScanResult.error('Rate Limit Exceeded: You have hit the public API quota limit (4 requests/min). Please try again later.');
    }
    return VTScanResult.error('VirusTotal API returned unexpected HTTP $code.');
  }
}
