import 'package:easy_localization/easy_localization.dart';
import 'package:obtainium/providers/notifications_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/source_provider.dart';
import '../providers/native_provider.dart';
import 'virustotal_service.dart';

class VTInterceptor {
  static final Set<String> oneTimeBypassList = {};

  static Future<bool> shouldAllowInstall(String appId, String apkFilePath, List<App> appsList, ) async {
    if (oneTimeBypassList.contains(appId)) {
      oneTimeBypassList.remove(appId);
      return true; // ONE-TIME WHITELIST BYPASS ACCEPTED
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final vtMode = prefs.getString('vtScanMode') ?? 'none';
      final apiKey = prefs.getString('vtApiKey-creds') ?? '';

      bool doScan = (vtMode == 'all');
      if (vtMode == 'selected') {
        try {
          final targetApp = appsList.firstWhere((a) => a.id == appId);
          if (targetApp.additionalSettings['scanWithVirusTotal'] == true) doScan = true;
        } catch (_) {}
      }

      if (doScan) {
        final vtRes = await VirusTotalService.scanApk(apkFilePath, apiKey);
        if (vtRes.isError) {
          bool strictGlobal = prefs.getBool('vtStrictScan') ?? false;
          bool strictApp = false;
          
          try {
            // Parse Obtainium's internal app database to find the override
            final appsJson = prefs.getStringList('apps') ?? [];
            for (var a in appsJson) {
              final map = jsonDecode(a);
              if (map['id'] == appId) {
                final additional = map['additionalAppSpecificSourceAgnosticSettings'];
                if (additional != null && additional['vtStrictScan'] == true) {
                  strictApp = true;
                }
                break;
              }
            }
          } catch (_) {}

          // ALWAYS generate incident payload so the notification click opens the dialog
          final payload = jsonEncode({
            "appName": appId,
            "title": tr('vtScanErrorTitle'),
            "summary": tr('vtScanErrorBody', args: [appId]),
            "detections": {"API Error": "Scan failed or timed out"},
          });
          final incidents = prefs.getStringList("vt_incident_unread") ?? [];
          incidents.add(payload);
          await prefs.setStringList("vt_incident_unread", incidents);
          await NativeFeatures.triggerVTError(appId);

          if (strictGlobal || strictApp) {
            return false; // STRICT MODE: Block install
          } else {
            return true;  // STANDARD MODE: Fail-open (allow install)
          }
        }
        if (!vtRes.passed) {
          try {
            final qFile = File(apkFilePath + ".vt_quarantine");
            await File(apkFilePath).copy(qFile.path);
          try { File(apkFilePath).deleteSync(); } catch (_) {}
            await prefs.setString("vt_q_" + appId, qFile.path);
          } catch (_) {}

          final payload = jsonEncode({
            "appName": appId,
            "title": vtRes.title,
            "summary": vtRes.summary,
            "detections": vtRes.detections,
          });
          final incidents = prefs.getStringList("vt_incident_unread") ?? [];
          incidents.add(payload);
          await prefs.setStringList("vt_incident_unread", incidents);
          await NativeFeatures.triggerVTAlert(appId);
          return false; // MALWARE DETECTED: ABORT INSTALL
        }
      }
    } catch (e) {
      print("VTInterceptor Exception: " + e.toString());
    }
    return true; // CLEAN: ALLOW INSTALL
  }
}