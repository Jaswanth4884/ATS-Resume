import 'dart:convert';

import 'package:http/http.dart' as http;

class GrammarIssue {
  final int start;
  final int end;
  final String message;
  final List<String> suggestions;

  const GrammarIssue({
    required this.start,
    required this.end,
    required this.message,
    required this.suggestions,
  });

  bool contains(int index) => index >= start && index <= end;
}

class GrammarCheckService {
  static const String _endpoint = 'https://api.languagetool.org/v2/check';
  static const Duration _timeout = Duration(seconds: 8);
  static final Map<String, List<GrammarIssue>> _cache = {};
  static final Map<String, Future<List<GrammarIssue>>> _pendingRequests = {};
  static const int _maxCacheEntries = 50;

  static Future<List<GrammarIssue>> checkText(
    String text, {
    String language = 'en-US',
  }) async {
    final trimmed = text.trim();
    if (trimmed.length < 3) {
      return const [];
    }

    final cacheKey = '$language::$text';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final pending = _pendingRequests[cacheKey];
    if (pending != null) {
      return pending;
    }

    final request = _fetchIssues(text, language: language, cacheKey: cacheKey);
    _pendingRequests[cacheKey] = request;
    return request;
  }

  static Future<List<GrammarIssue>> _fetchIssues(
    String text, {
    required String language,
    required String cacheKey,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'text': text, 'language': language},
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }

      final matches = decoded['matches'];
      if (matches is! List) {
        return const [];
      }

      final issues = <GrammarIssue>[];
      for (final item in matches.whereType<Map>()) {
        final offset = (item['offset'] as num?)?.toInt();
        final length = (item['length'] as num?)?.toInt();
        final message = (item['message'] ?? '').toString().trim();
        if (offset == null || length == null || length <= 0) {
          continue;
        }

        final replacements = item['replacements'];
        final suggestions = <String>[];
        if (replacements is List) {
          for (final replacement in replacements.whereType<Map>()) {
            final value = (replacement['value'] ?? '').toString().trim();
            if (value.isNotEmpty && !suggestions.contains(value)) {
              suggestions.add(value);
            }
          }
        }

        issues.add(
          GrammarIssue(
            start: offset,
            end: offset + length,
            message: message.isEmpty
                ? 'Spelling/grammar issue detected'
                : message,
            suggestions: suggestions,
          ),
        );
      }

      issues.sort((left, right) => left.start.compareTo(right.start));
      final normalized = _normalizeIssues(issues);
      _remember(cacheKey, normalized);
      return normalized;
    } catch (_) {
      return const [];
    } finally {
      _pendingRequests.remove(cacheKey);
    }
  }

  static List<GrammarIssue> _normalizeIssues(List<GrammarIssue> issues) {
    if (issues.isEmpty) {
      return issues;
    }

    final normalized = <GrammarIssue>[];
    GrammarIssue? current;

    for (final issue in issues) {
      final active = current;
      if (active == null) {
        current = issue;
        continue;
      }

      if (issue.start <= active.end) {
        final mergedEnd = issue.end > active.end ? issue.end : active.end;
        final mergedSuggestions = <String>{
          ...active.suggestions,
          ...issue.suggestions,
        }.toList();
        current = GrammarIssue(
          start: active.start,
          end: mergedEnd,
          message: active.message,
          suggestions: mergedSuggestions,
        );
      } else {
        normalized.add(active);
        current = issue;
      }
    }

    if (current != null) {
      normalized.add(current);
    }

    return normalized;
  }

  static void _remember(String cacheKey, List<GrammarIssue> issues) {
    if (_cache.length >= _maxCacheEntries) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    _cache[cacheKey] = issues;
  }
}
