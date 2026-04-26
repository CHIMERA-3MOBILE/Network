import 'dart:developer' as developer;
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  static const int _maxLogFiles = 5;
  static const int _maxLogSize = 1024 * 1024; // 1MB

  Future<void> log(String level, String message, {String? tag, dynamic error, StackTrace? stackTrace}) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final tagStr = tag ?? 'NetworkApp';
    final logMessage = '[$timestamp] [$level] [$tagStr] $message';
    
    // Console logging
    if (level == 'ERROR') {
      developer.log(logMessage, error: error, stackTrace: stackTrace);
    } else if (level == 'WARNING') {
      developer.log(logMessage);
    } else {
      developer.log(logMessage);
    }
    
    // File logging
    await _writeToFile(logMessage);
    
    // Error details
    if (error != null) {
      await _writeToFile('Error: $error');
    }
    if (stackTrace != null) {
      await _writeToFile('StackTrace: $stackTrace');
    }
  }

  Future<void> debug(String message, {String? tag}) => log('DEBUG', message, tag: tag);
  Future<void> info(String message, {String? tag}) => log('INFO', message, tag: tag);
  Future<void> warning(String message, {String? tag}) => log('WARNING', message, tag: tag);
  Future<void> error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) => 
      log('ERROR', message, tag: tag, error: error, stackTrace: stackTrace);

  Future<void> _writeToFile(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      final now = DateTime.now();
      final logFileName = 'network_app_${DateFormat('yyyy_MM_dd').format(now)}.log';
      final logFile = File('${logDir.path}/$logFileName');
      
      // Check file size and rotate if necessary
      if (await logFile.exists()) {
        final fileSize = await logFile.length();
        if (fileSize > _maxLogSize) {
          await _rotateLogFiles(logDir);
        }
      }
      
      await logFile.writeAsString('$message\n', mode: FileMode.append);
    } catch (e) {
      developer.log('Failed to write log to file: $e');
    }
  }

  Future<void> _rotateLogFiles(Directory logDir) async {
    try {
      final files = await logDir.list().where((entity) => 
          entity is File && entity.path.endsWith('.log')).cast<File>().toList();
      
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      
      // Remove oldest files if we have too many
      while (files.length >= _maxLogFiles) {
        final oldestFile = files.removeAt(0);
        await oldestFile.delete();
      }
      
      // Rename current file with timestamp
      final now = DateTime.now();
      final timestamp = DateFormat('HH_mm_ss').format(now);
      for (final file in files) {
        if (file.path.contains('network_app_')) {
          final newPath = file.path.replaceAll('.log', '_$timestamp.log');
          await file.rename(newPath);
        }
      }
    } catch (e) {
      developer.log('Failed to rotate log files: $e');
    }
  }

  Future<List<String>> getLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (!await logDir.exists()) {
        return [];
      }
      
      final files = await logDir.list().where((entity) => 
          entity is File && entity.path.endsWith('.log')).cast<File>().toList();
      
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      return files.map((file) => file.path).toList();
    } catch (e) {
      developer.log('Failed to get log files: $e');
      return [];
    }
  }

  Future<String> getLogFileContent(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return 'File not found';
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  Future<void> clearLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (await logDir.exists()) {
        await logDir.delete(recursive: true);
      }
    } catch (e) {
      developer.log('Failed to clear logs: $e');
    }
  }
}
