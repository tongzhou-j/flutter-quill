import 'package:html/parser.dart' as htmlParse;
import 'package:html/dom.dart' as htmlDom;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

class HtmlToDeltaConverter {
  static const _COLOR_PATTERN = r'[^-]color:#[a-fA-F0-9]{6,8}';
  static const _BG_COLOR_PATTERN = r'background-color:#[a-fA-F0-9]{6,8}';

  static quill.Delta _parseInlineStyles(htmlDom.Element element,{Map<String, dynamic>? topAttributes}) {
    var delta = quill.Delta();

    for (final node in element.nodes) {
      final attributes = _parseElementStyles(element);
      if (topAttributes != null) {
        attributes.addEntries(topAttributes.entries);
      }
      if (node is htmlDom.Text) {
        delta.insert(node.text, attributes);
      } else if (node is htmlDom.Element && node.localName == 'img') {
        final src = node.attributes['src'];
        if (src != null) {
          delta..insert({'image': src});
        }
      } else if (node is htmlDom.Element) {
        if (node.localName == 'br') {
          delta = delta..insert('\n');
        }else {
          delta = delta.concat(_parseInlineStyles(node,topAttributes: attributes));
        }
      }
    }

    return delta;
  }

  static Map<String, dynamic> _parseElementStyles(htmlDom.Element element) {
    Map<String, dynamic> attributes = {};
    if (element.localName == 'strong' ||
        (element.parent?.localName == 'strong')) attributes['bold'] = true;
    if (element.localName == 'em' || (element.parent?.localName == 'em'))
      attributes['italic'] = true;
    if (element.localName == 'u' || (element.parent?.localName == 'u'))
      attributes['underline'] = true;
    if (element.localName == 'del') attributes['strike'] = true;

    final style = element.attributes['style'];
    if (style != null) {
      final colorValue = _parseColorFromStyle(style);
      if (colorValue != null) {
        List colorList = colorValue.split(":");
        attributes['color'] = colorList.last;
      }

      final bgColorValue = _parseBackgroundColorFromStyle(style);
      if (bgColorValue != null) {
        List colorList = bgColorValue.split(":");
        attributes['background'] = colorList.last;
      }
      if (style.contains("italic")) {
        attributes['italic'] = true;
      }
      if (style.contains("bold")) {
        attributes['bold'] = true;
      }
      if (style.contains("bold")) {
        attributes['bold'] = true;
      }
    }

    return attributes;
  }

  static String? _parseColorFromStyle(String style) {
    if (RegExp("color:").hasMatch(style)) {
      String newStyleText = "\"" + style;
      String? color = RegExp(_COLOR_PATTERN).stringMatch(newStyleText);
      return color;
    }
    return null;
  }

  static String? _parseBackgroundColorFromStyle(String style) {
    if (RegExp('background-color:').hasMatch(style)) {
      String? color = RegExp(_BG_COLOR_PATTERN).stringMatch(style);
      return color;
    }
    return null;
  }

  static String? _parseRgbColorFromMatch(RegExpMatch? colorMatch) {
    if (colorMatch != null) {
      try {
        final red = int.parse(colorMatch.group(1)!);
        final green = int.parse(colorMatch.group(2)!);
        final blue = int.parse(colorMatch.group(3)!);
        return '#${red.toRadixString(16).padLeft(2, '0')}${green.toRadixString(16).padLeft(2, '0')}${blue.toRadixString(16).padLeft(2, '0')}';
      } catch (e) {
        // debugPrintStack(label: e.toString());
      }
    }
    return null;
  }

  static quill.Delta htmlToDelta(String html) {
    final document = htmlParse.parse(html);
    var delta = quill.Delta();

    quill.Delta result =
    delta.concat(converterDelta(document.body));
    // print("result === ");
    // print(result.toJson());
    return html.isNotEmpty ? result : quill.Delta()
      ..insert('\n');
  }

  static quill.Delta converterDelta(htmlDom.Element? e) {
    var delta = quill.Delta();
    for (final node in e?.nodes ?? []) {
      if (node is htmlDom.Element) {
        switch (node.localName) {
          case 'p':
            delta = delta.concat(_parseInlineStyles(node))..insert('\n');
            break;
          case 'span':
            delta = delta.concat(_parseInlineStyles(node));
            break;
          case 'li':
            String listValue =
            node.parent?.localName == "ul" ? "bullet" : "ordered";
            delta = delta.concat(_parseInlineStyles(node))
              ..insert('\n', {"list": listValue});
            break;
          case 'ol':
          case 'ul':
            quill.Delta subDelta = converterDelta(node);
            delta = delta.concat(subDelta);
            break;
          case 'br':
            delta = delta..insert('\n');
            break;
        }
      }
    }
    return delta;
  }
}

String deltaToHtml(quill.Delta delta) {
  List deltaJson = delta.toJson();
  List<Map<String, dynamic>> newjson = deltaJson.map((e) {
    Map<String, dynamic> item = e;
    replaceColor(item);
    return item;
  }).toList();
  QuillDeltaToHtmlConverter converter = QuillDeltaToHtmlConverter(
      newjson,
      ConverterOptions(
          converterOptions: OpConverterOptions(
            inlineStylesFlag: true,
            // inlineStyles: InlineStyles({
            //   }
            // ),
          )));

  final result = converter.convert();
  return result;
}

void replaceColor(Map item) {
  item.forEach((key, value) {
    if (value is String) {
      if (key == 'color' && value.length > 7) {
        item[key] = value.replaceAll('#FF', '#');
      }
      if (key == 'background' && value.length > 7) {
        item[key] = value.replaceAll('#FF', '#');
      }
    } else if (value is Map) {
      replaceColor(value);
    }
  });
}
