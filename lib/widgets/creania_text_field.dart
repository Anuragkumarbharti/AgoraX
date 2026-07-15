import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';

enum CreaniaInputType {
  name,
  username,
  email,
  phone,
  otp,
  password,
  confirmPassword,
  bio,
  description,
  search,
  amount,
  coins,
  age,
  website,
  instagram,
  youtube,
  facebook,
  twitter,
  linkedin,
  github,
  pin,
  verificationCode,
  walletAmount,
  roomID,
  userID,
  tags,
  feedback,
  report,
}

class CreaniaTextField extends StatefulWidget {
  final CreaniaInputType type;
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool autofocus;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  const CreaniaTextField({
    Key? key,
    required this.type,
    this.controller,
    this.hintText,
    this.labelText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.autofocus = false,
    this.maxLength,
    this.textInputAction,
    this.focusNode,
  }) : super(key: key);

  @override
  State<CreaniaTextField> createState() => _CreaniaTextFieldState();
}

class _CreaniaTextFieldState extends State<CreaniaTextField> {
  bool _obscureText = true;
  late FocusNode _effectiveFocusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.type == CreaniaInputType.password ||
        widget.type == CreaniaInputType.confirmPassword ||
        widget.type == CreaniaInputType.pin;
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    } else {
      _effectiveFocusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _effectiveFocusNode.hasFocus;
    });
  }

  TextInputType get _keyboardType {
    switch (widget.type) {
      case CreaniaInputType.email:
        return TextInputType.emailAddress;
      case CreaniaInputType.phone:
        return TextInputType.phone;
      case CreaniaInputType.otp:
      case CreaniaInputType.coins:
      case CreaniaInputType.age:
      case CreaniaInputType.pin:
      case CreaniaInputType.verificationCode:
      case CreaniaInputType.roomID:
      case CreaniaInputType.userID:
        return TextInputType.number;
      case CreaniaInputType.amount:
      case CreaniaInputType.walletAmount:
        return const TextInputType.numberWithOptions(decimal: true);
      case CreaniaInputType.bio:
      case CreaniaInputType.description:
      case CreaniaInputType.feedback:
      case CreaniaInputType.report:
        return TextInputType.multiline;
      case CreaniaInputType.website:
      case CreaniaInputType.instagram:
      case CreaniaInputType.youtube:
      case CreaniaInputType.facebook:
      case CreaniaInputType.twitter:
      case CreaniaInputType.linkedin:
      case CreaniaInputType.github:
        return TextInputType.url;
      case CreaniaInputType.search:
        return TextInputType.text;
      default:
        return TextInputType.text;
    }
  }

  TextCapitalization get _textCapitalization {
    switch (widget.type) {
      case CreaniaInputType.name:
        return TextCapitalization.words;
      case CreaniaInputType.bio:
      case CreaniaInputType.description:
      case CreaniaInputType.feedback:
      case CreaniaInputType.report:
        return TextCapitalization.sentences;
      default:
        return TextCapitalization.none;
    }
  }

  List<TextInputFormatter> get _inputFormatters {
    List<TextInputFormatter> formatters = [];
    if (widget.type == CreaniaInputType.username) {
      formatters.add(FilteringTextInputFormatter.deny(RegExp(r'\s')));
    }
    if (widget.type == CreaniaInputType.otp ||
        widget.type == CreaniaInputType.coins ||
        widget.type == CreaniaInputType.age ||
        widget.type == CreaniaInputType.roomID ||
        widget.type == CreaniaInputType.userID ||
        widget.type == CreaniaInputType.verificationCode ||
        widget.type == CreaniaInputType.pin) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
    }
    // Block emojis for username, email, phone, otp, urls
    if (widget.type == CreaniaInputType.username ||
        widget.type == CreaniaInputType.email ||
        widget.type == CreaniaInputType.phone ||
        widget.type == CreaniaInputType.otp ||
        widget.type == CreaniaInputType.pin ||
        widget.type == CreaniaInputType.website ||
        widget.type == CreaniaInputType.instagram ||
        widget.type == CreaniaInputType.youtube ||
        widget.type == CreaniaInputType.facebook ||
        widget.type == CreaniaInputType.twitter ||
        widget.type == CreaniaInputType.linkedin ||
        widget.type == CreaniaInputType.github) {
      formatters.add(FilteringTextInputFormatter.deny(
        RegExp(r'[\u2700-\u27BF]|[\uE000-\uF8FF]|\uD83C[\uDC00-\uDFFF]|\uD83D[\uDC00-\uDFFF]|[\u2011-\u26FF]|\uD83E[\uDD00-\uDFFF]')
      ));
    }
    return formatters;
  }

  Iterable<String>? get _autofillHints {
    switch (widget.type) {
      case CreaniaInputType.email:
        return [AutofillHints.email];
      case CreaniaInputType.phone:
        return [AutofillHints.telephoneNumber];
      case CreaniaInputType.password:
        return [AutofillHints.password];
      case CreaniaInputType.otp:
        return [AutofillHints.oneTimeCode];
      default:
        return null;
    }
  }

  int get _maxLines {
    if (widget.type == CreaniaInputType.bio ||
        widget.type == CreaniaInputType.description ||
        widget.type == CreaniaInputType.feedback ||
        widget.type == CreaniaInputType.report) {
      return 5;
    }
    return 1;
  }

  int? get _maxLength {
    if (widget.maxLength != null) return widget.maxLength;
    if (widget.type == CreaniaInputType.bio) return 160;
    if (widget.type == CreaniaInputType.description) return 500;
    if (widget.type == CreaniaInputType.feedback || widget.type == CreaniaInputType.report) return 1000;
    if (widget.type == CreaniaInputType.otp) return 6;
    if (widget.type == CreaniaInputType.pin) return 4;
    return null;
  }

  bool get _isPasswordField =>
      widget.type == CreaniaInputType.password ||
      widget.type == CreaniaInputType.confirmPassword;

  @override
  Widget build(BuildContext context) {
    final hasShadow = !_isFocused;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _effectiveFocusNode,
        keyboardType: _keyboardType,
        textCapitalization: _textCapitalization,
        obscureText: _obscureText,
        autofocus: widget.autofocus,
        maxLength: _maxLength,
        maxLines: _maxLines,
        minLines: 1,
        inputFormatters: _inputFormatters,
        autofillHints: _autofillHints,
        style: context.inputTextStyle,
        textInputAction: widget.textInputAction ??
            (_maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
        decoration: InputDecoration(
          hintText: widget.hintText,
          labelText: widget.labelText,
          suffixIcon: _isPasswordField
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: context.caption,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : widget.type == CreaniaInputType.search
                  ? Icon(Icons.search_rounded, color: context.caption, size: 22)
                  : null,
          counterText: "", // Hide default counter to place custom counter if needed
        ),
        validator: (value) {
          if (widget.validator != null) {
            return widget.validator!(value);
          }
          if (value == null || value.trim().isEmpty) {
            return 'Field cannot be empty';
          }
          if (widget.type == CreaniaInputType.email) {
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(value)) {
              return 'Please enter a valid email address';
            }
          }
          if (widget.type == CreaniaInputType.phone) {
            if (value.length < 10) {
              return 'Please enter a valid phone number';
            }
          }
          return null;
        },
        onChanged: (val) {
          // Auto trim spaces where not needed
          if (widget.type == CreaniaInputType.username ||
              widget.type == CreaniaInputType.email ||
              widget.type == CreaniaInputType.otp ||
              widget.type == CreaniaInputType.pin) {
            final trimmed = val.replaceAll(' ', '');
            if (trimmed != val) {
              widget.controller?.value = widget.controller!.value.copyWith(
                text: trimmed,
                selection: TextSelection.collapsed(offset: trimmed.length),
              );
            }
          }
          if (widget.onChanged != null) {
            widget.onChanged!(val);
          }
        },
        onFieldSubmitted: widget.onFieldSubmitted,
      ),
    );
  }
}
