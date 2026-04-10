import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/grammar_check_service.dart';

class GrammarAwareTextEditingController extends TextEditingController {
  List<GrammarIssue> _issues = const [];

  List<GrammarIssue> get issues => _issues;

  void setIssues(List<GrammarIssue> issues) {
    if (_issuesEqual(_issues, issues)) {
      return;
    }
    _issues = issues;
    notifyListeners();
  }

  bool _issuesEqual(List<GrammarIssue> left, List<GrammarIssue> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.start != b.start ||
          a.end != b.end ||
          a.message != b.message ||
          a.suggestions.length != b.suggestions.length) {
        return false;
      }
      for (
        var suggestionIndex = 0;
        suggestionIndex < a.suggestions.length;
        suggestionIndex++
      ) {
        if (a.suggestions[suggestionIndex] != b.suggestions[suggestionIndex]) {
          return false;
        }
      }
    }
    return true;
  }

  GrammarIssue? issueAt(int index) {
    for (final issue in _issues) {
      if (issue.contains(index)) {
        return issue;
      }
    }
    return null;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final text = value.text;

    if (text.isEmpty || _issues.isEmpty) {
      return TextSpan(style: baseStyle, text: text);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final issue in _issues) {
      if (issue.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, issue.start)));
      }

      final end = issue.end > text.length ? text.length : issue.end;
      if (issue.start < end) {
        spans.add(
          TextSpan(
            text: text.substring(issue.start, end),
            style: baseStyle.copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: Colors.redAccent,
              decorationThickness: 1.6,
            ),
          ),
        );
      }

      cursor = end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}

class GrammarAwareTextField extends StatefulWidget {
  final GrammarAwareTextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextStyle? style;
  final InputDecoration decoration;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final bool expands;
  final bool autocorrect;
  final bool enableSuggestions;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final String languageCode;
  final bool showSuggestionsOnTap;
  final bool grammarCheckEnabled;
  final EdgeInsetsGeometry? contentPadding;
  final String? hintTextOverride;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;

  const GrammarAwareTextField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.decoration,
    this.style,
    this.maxLines,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.expands = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
    this.languageCode = 'en-US',
    this.showSuggestionsOnTap = true,
    this.grammarCheckEnabled = true,
    this.contentPadding,
    this.hintTextOverride,
    this.onTap,
    this.onEditingComplete,
  });

  @override
  State<GrammarAwareTextField> createState() => _GrammarAwareTextFieldState();
}

class _GrammarAwareTextFieldState extends State<GrammarAwareTextField> {
  Timer? _debounceTimer;
  Timer? _selectionDebounceTimer;
  String _lastCheckedText = '';
  bool _requestSuggestionOnNextSelectionChange = false;
  bool _isChecking = false;
  bool _suppressSelectionTriggeredMenu = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_handleControllerChange);
    _scheduleCheck(widget.controller.text);
  }

  @override
  void didUpdateWidget(covariant GrammarAwareTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      _scheduleCheck(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _debounceTimer?.cancel();
    _selectionDebounceTimer?.cancel();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleControllerChange() {
    final text = widget.controller.text;
    if (text == _lastCheckedText) {
      _handleSelectionChange();
      return;
    }
    _scheduleCheck(text);
  }

  void _scheduleCheck(String text, {bool immediate = false}) {
    if (!widget.grammarCheckEnabled) {
      widget.controller.setIssues(const []);
      if (mounted && _isChecking) {
        setState(() {
          _isChecking = false;
        });
      }
      return;
    }

    _debounceTimer?.cancel();
    if (text.trim().length < 3) {
      _lastCheckedText = text;
      widget.controller.setIssues(const []);
      if (mounted && _isChecking) {
        setState(() {
          _isChecking = false;
        });
      }
      return;
    }

    final delay = immediate ? Duration.zero : const Duration(milliseconds: 420);

    if (delay == Duration.zero) {
      _runCheck(text);
      return;
    }

    _debounceTimer = Timer(delay, () {
      _runCheck(text);
    });
  }

  Future<void> _runCheck(String text) async {
    if (!mounted) {
      return;
    }

    if (!_isChecking) {
      setState(() {
        _isChecking = true;
      });
    }

    final issues = await GrammarCheckService.checkText(
      text,
      language: widget.languageCode,
    );

    if (!mounted || widget.controller.text != text) {
      return;
    }

    _lastCheckedText = text;
    widget.controller.setIssues(issues);

    if (mounted && _isChecking) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  void _handleTap() {
    if (!widget.showSuggestionsOnTap) {
      return;
    }
    _requestSuggestionOnNextSelectionChange = true;

    _selectionDebounceTimer?.cancel();
    _selectionDebounceTimer = Timer(const Duration(milliseconds: 80), () {
      _maybeShowSuggestionsForCurrentSelection();
    });
  }

  void _handleSelectionChange() {
    if (_suppressSelectionTriggeredMenu) {
      return;
    }

    if (!_requestSuggestionOnNextSelectionChange) {
      return;
    }

    _maybeShowSuggestionsForCurrentSelection();
  }

  Future<void> _maybeShowSuggestionsForCurrentSelection() async {
    if (!_requestSuggestionOnNextSelectionChange || !mounted) {
      return;
    }

    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _requestSuggestionOnNextSelectionChange = false;
      return;
    }

    final issue = widget.controller.issueAt(selection.baseOffset);
    if (issue == null) {
      _requestSuggestionOnNextSelectionChange = false;
      return;
    }

    _requestSuggestionOnNextSelectionChange = false;
    await _showSuggestions(issue);
  }

  Future<void> _showSuggestions(GrammarIssue issue) async {
    if (!mounted) {
      return;
    }

    final suggestions = issue.suggestions;
    final text = issue.message;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.spellcheck,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Correction suggestions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 16),
                if (suggestions.isEmpty)
                  const Text(
                    'No replacement suggestions available.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  )
                else
                  ...suggestions.map(
                    (suggestion) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _applySuggestion(issue, suggestion);
                          },
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            foregroundColor: const Color(0xFF1F2937),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          child: Text(suggestion),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Dismiss'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _ignoreIssue(issue);
                      },
                      child: const Text('Ignore'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applySuggestion(GrammarIssue issue, String suggestion) {
    final text = widget.controller.text;
    if (issue.end > text.length || issue.start < 0 || issue.start > issue.end) {
      return;
    }

    final newText = text.replaceRange(issue.start, issue.end, suggestion);
    final newSelection = TextSelection.collapsed(
      offset: issue.start + suggestion.length,
    );

    _suppressSelectionTriggeredMenu = true;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: newSelection,
      composing: TextRange.empty,
    );
    _suppressSelectionTriggeredMenu = false;
    widget.onChanged(newText);
    _scheduleCheck(newText);
  }

  void _ignoreIssue(GrammarIssue issue) {
    final current = widget.controller.issues;
    final filtered = current.where((item) {
      return item.start != issue.start || item.end != issue.end;
    }).toList();
    widget.controller.setIssues(filtered);
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration.copyWith(
      hintText: widget.hintTextOverride ?? widget.decoration.hintText,
      contentPadding: widget.contentPadding ?? widget.decoration.contentPadding,
      suffixIcon: _buildSuffixIcon(),
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _handleTap(),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: widget.style,
        decoration: decoration,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        readOnly: widget.readOnly,
        enabled: widget.enabled,
        obscureText: widget.obscureText,
        expands: widget.expands,
        autocorrect: widget.autocorrect,
        enableSuggestions: widget.enableSuggestions,
        inputFormatters: widget.inputFormatters,
        textAlign: widget.textAlign,
        onChanged: (value) {
          widget.onChanged(value);
        },
        onTap: () {
          widget.onTap?.call();
          _handleTap();
        },
        onEditingComplete: widget.onEditingComplete,
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isChecking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return widget.decoration.suffixIcon;
  }
}
