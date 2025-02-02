// MIT License
//
// Copyright (c) 2020 J-P Nurmi <jpnurmi@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'custom_double_converter.dart';
import 'spin_formatter.dart';

// ignore_for_file: public_member_api_docs

abstract class BaseSpinBox extends StatefulWidget {
  const BaseSpinBox({Key? key}) : super(key: key);

  double get min;
  double get max;
  double get step;
  double? get pageStep;
  double get value;
  int get decimals;
  int get digits;
  void Function(double)? get onSubmitted;
  ValueChanged<double>? get onChanged;
  bool Function(double value)? get canChange;
  CustomDoubleConverter? get customDoubleConverter; 
  VoidCallback? get beforeChange;
  VoidCallback? get afterChange;
  bool get readOnly;
  FocusNode? get focusNode;
}

mixin SpinBoxMixin<T extends BaseSpinBox> on State<T> {
  late double _value;
  late double _cachedValue;
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  double get value => _value;
  bool get hasFocus => _focusNode.hasFocus;
  FocusNode get focusNode => _focusNode;
  TextEditingController get controller => _controller;
  TextInputFormatter get formatter => SpinFormatter(
      min: widget.min, max: widget.max, decimals: widget.decimals);
      
  double _parseValue(String text) {
     final double value = widget.customDoubleConverter?.stringToDouble(text)??double.tryParse(text) ?? 0;
     //print("_parseValue text:$text value:$value");
     return value;
  }

  /*
  String _formatText(double value) {
    if (widget.customDoubleConverter==null) {
      return value.toStringAsFixed(widget.decimals).padLeft(widget.digits, '0');
    } else {
      final String str =  
        _focusNode.hasFocus?
        value.toStringAsFixed(widget.decimals).padLeft(widget.digits, '0'):
        widget.customDoubleConverter?.doubleToString(value)??
        value.toStringAsFixed(widget.decimals).padLeft(widget.digits, '0');
      //print("_formatText value:$value str:$str");
      return str;  
    }
  }
  */

  String _formatNumber(double val) => val.toStringAsFixed(widget.decimals).padLeft(widget.digits, '0');

  String _formatText(double value) {
    // Define the base format function

    // Determine the formatting based on focus state and custom converter availability
    return _focusNode.hasFocus || widget.customDoubleConverter == null
        ? _formatNumber(value)
        : widget.customDoubleConverter!.doubleToString(value);
  }

  Map<ShortcutActivator, VoidCallback> get bindings {
    return {
      // ### TODO: use SingleActivator fixed in Flutter 2.10+
      // https://github.com/flutter/flutter/issues/92717
      LogicalKeySet(LogicalKeyboardKey.arrowUp): _stepUp,
      LogicalKeySet(LogicalKeyboardKey.arrowDown): _stepDown,
      if (widget.pageStep != null) ...{
        LogicalKeySet(LogicalKeyboardKey.pageUp): _pageStepUp,
        LogicalKeySet(LogicalKeyboardKey.pageDown): _pageStepDown,
      }
    };
  }

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _cachedValue = widget.value;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _controller = TextEditingController(text: _formatText(_value));
    _controller.addListener(_updateValue);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _stepUp() => setValue(value + widget.step);
  void _stepDown() => setValue(value - widget.step);

  void _pageStepUp() => setValue(value + widget.pageStep!);
  void _pageStepDown() => setValue(value - widget.pageStep!);

  void _updateValue() {
    final v = _parseValue(_controller.text);
    if (v == _value) return;

    //print("_updateValue v:$v _value:$_value");

    if (widget.canChange?.call(v) == false) {
      controller.text = _formatText(_cachedValue);
      setState(() {
        _value = _cachedValue;
      });
      return;
    }

    setState(() => _value = v);
    widget.onChanged?.call(v);
  }

  void setValue(double v) {
    //print("setValue v:$v value:$value");
    final newValue = v.clamp(widget.min, widget.max);
    if (newValue == value) return;

    if (widget.canChange?.call(newValue) == false) return;

    widget.beforeChange?.call();
    setState(() => _updateController(value, newValue));
    widget.onSubmitted?.call(double.parse(_formatText(newValue)));
    widget.afterChange?.call();
  }

  void _updateController(double oldValue, double newValue) {
    //print("_updateController oldValue:$oldValue newValue:$newValue");

    //No need to change controller when we are already within editting
    if (!focusNode.hasFocus) {
      final text = _formatText(newValue);
      final selection = _controller.selection;
      final oldOffset = value.isNegative ? 1 : 0;
      final newOffset = _parseValue(text).isNegative ? 1 : 0;

      _controller.value = _controller.value.copyWith(
        text: text,
        selection: selection.copyWith(
          baseOffset: selection.baseOffset - oldOffset + newOffset,
          extentOffset: selection.extentOffset - oldOffset + newOffset,
        ),
      );
    }
  }

  @protected
  double fixupValue(String value) {
    final v = _parseValue(value);
    //print("fixupValue(entered) value:$value v:$v _value:$_value _cachedValue:$_cachedValue");
    if (value.isEmpty || (v < widget.min || v > widget.max)) {
      // will trigger notify to _updateValue()
    } else {
      _cachedValue = _value;
      //if (widget.customDoubleConverter!=null) {
      //}
    }
    _controller.text = _formatText(_cachedValue);
    //print("fixupValue(exit) value:$value v:$v _value:$_value _cachedValue:$_cachedValue");
    return _cachedValue;
  }

  void _handleFocusChanged() {
    //print("_handleFocusChanged:$hasFocus text:${_controller.text} cval:${_controller.value} widget.value:${widget.value}");
    setState(() {
      if (hasFocus) {
        _controller.text=_formatNumber(_cachedValue);
        _selectAll();
        //print("_handleFocusChanged(after selectAll) text:${_controller.text}");
      } else {
        final value = fixupValue(_controller.text);
        //print("_handleFocusChanged(after fixupValue) text:${_controller.text} value:$value cval:${_controller.value}");
        widget.onSubmitted?.call(value);
      }
    });
  }

  void _selectAll() {
    _controller.selection = _controller.selection
        .copyWith(baseOffset: 0, extentOffset: _controller.text.length);
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.removeListener(_updateValue);
      _value = _cachedValue = widget.value;
      _updateController(oldWidget.value, widget.value);
      _controller.addListener(_updateValue);
    }
  }
}
