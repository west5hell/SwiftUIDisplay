//
//  HTMLView.swift
//  SwiftUIDisplay
//
//  Created by Pongt Chia on 26/5/26.
//

import SwiftUI

// MARK: - HTML Node Model

indirect enum HTMLNode {
    case text(String)
    case element(tag: String, attributes: [String: String], children: [HTMLNode])
}

// MARK: - Simple HTML Parser

struct HTMLParser {
    static func parse(_ html: String) -> [HTMLNode] {
        var nodes: [HTMLNode] = []
        var index = html.startIndex

        while index < html.endIndex {
            if html[index] == "<" {
                // Try to parse a tag
                if let (node, next) = parseElement(html, from: index) {
                    nodes.append(node)
                    index = next
                } else {
                    // Not a valid tag, treat as text
                    nodes.append(.text(String(html[index])))
                    index = html.index(after: index)
                }
            } else {
                // Parse text node
                let (text, next) = parseText(html, from: index)
                if !text.isEmpty {
                    nodes.append(.text(text))
                }
                index = next
            }
        }
        return nodes
    }

    private static func parseText(_ html: String, from start: String.Index) -> (String, String.Index) {
        var index = start
        var text = ""
        while index < html.endIndex && html[index] != "<" {
            text.append(html[index])
            index = html.index(after: index)
        }
        return (decodeHTMLEntities(text), index)
    }

    private static func parseElement(_ html: String, from start: String.Index) -> (HTMLNode, String.Index)? {
        guard html[start] == "<" else { return nil }
        var index = html.index(after: start)

        // Skip closing tags at top level (handled by parent)
        if index < html.endIndex && html[index] == "/" {
            return nil
        }

        // Skip comments
        if html[index...].hasPrefix("!--") {
            if let end = html.range(of: "-->", range: index..<html.endIndex) {
                return (.text(""), end.upperBound)
            }
            return nil
        }

        // Parse tag name
        var tagName = ""
        while index < html.endIndex && html[index] != " " && html[index] != ">" && html[index] != "/" {
            tagName.append(html[index])
            index = html.index(after: index)
        }
        tagName = tagName.lowercased()
        guard !tagName.isEmpty else { return nil }

        // Parse attributes
        var attributes: [String: String] = [:]
        while index < html.endIndex && html[index] != ">" && html[index] != "/" {
            // Skip whitespace
            while index < html.endIndex && html[index] == " " {
                index = html.index(after: index)
            }
            if html[index] == ">" || html[index] == "/" { break }

            // Attribute name
            var attrName = ""
            while index < html.endIndex && html[index] != "=" && html[index] != " " && html[index] != ">" {
                attrName.append(html[index])
                index = html.index(after: index)
            }

            var attrValue = ""
            if index < html.endIndex && html[index] == "=" {
                index = html.index(after: index)
                let quote = html[index]
                if quote == "\"" || quote == "'" {
                    index = html.index(after: index)
                    while index < html.endIndex && html[index] != quote {
                        attrValue.append(html[index])
                        index = html.index(after: index)
                    }
                    if index < html.endIndex { index = html.index(after: index) }
                }
            }
            if !attrName.isEmpty {
                attributes[attrName.lowercased()] = attrValue
            }
        }

        // Self-closing
        let selfClosing = index < html.endIndex && html[index] == "/"
        // Advance past ">"
        while index < html.endIndex && html[index] != ">" {
            index = html.index(after: index)
        }
        if index < html.endIndex { index = html.index(after: index) }

        let voidElements = ["br", "hr", "img", "input", "link", "meta", "area", "base", "col", "embed", "param", "source", "track", "wbr"]
        if selfClosing || voidElements.contains(tagName) {
            return (.element(tag: tagName, attributes: attributes, children: []), index)
        }

        // Parse children until closing tag
        var children: [HTMLNode] = []
        let closeTag = "</\(tagName)>"

        while index < html.endIndex {
            let remaining = html[index...]
            if remaining.lowercased().hasPrefix(closeTag) {
                index = html.index(index, offsetBy: closeTag.count)
                break
            }

            if html[index] == "<" {
                // Check if it's a closing tag for this element
                let afterLt = html.index(after: index)
                if afterLt < html.endIndex && html[afterLt] == "/" {
                    // It's some closing tag — check if it's ours or a parent's
                    if remaining.lowercased().hasPrefix(closeTag) {
                        index = html.index(index, offsetBy: closeTag.count)
                    }
                    break
                }

                if let (child, next) = parseElement(html, from: index) {
                    children.append(child)
                    index = next
                } else {
                    children.append(.text(String(html[index])))
                    index = html.index(after: index)
                }
            } else {
                let (text, next) = parseText(html, from: index)
                if !text.isEmpty {
                    children.append(.text(text))
                }
                index = next
            }
        }

        return (.element(tag: tagName, attributes: attributes, children: children), index)
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: "\u{00A0}")
    }
}

// MARK: - HTML Renderer

struct HTMLView: View {
    let html: String

    var body: some View {
        let nodes = HTMLParser.parse(html)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                HTMLNodeView(node: node, context: .block)
            }
        }
    }
}

// MARK: - Rendering Context

enum RenderContext {
    case block
    case inline
    case listItem(ordered: Bool, index: Int)
}

// MARK: - Node View

struct HTMLNodeView: View {
    let node: HTMLNode
    let context: RenderContext
    var listIndex: Int = 0

    var body: some View {
        switch node {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                Text(trimmed)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .element(let tag, let attributes, let children):
            renderElement(tag: tag, attributes: attributes, children: children)
        }
    }

    @ViewBuilder
    private func renderElement(tag: String, attributes: [String: String], children: [HTMLNode]) -> some View {
        switch tag {

        // MARK: Block elements
        case "p":
            inlineText(children)
                .padding(.vertical, 2)

        case "h1":
            inlineText(children)
                .font(.system(size: 28, weight: .bold))
                .padding(.vertical, 4)

        case "h2":
            inlineText(children)
                .font(.system(size: 22, weight: .bold))
                .padding(.vertical, 3)

        case "h3":
            inlineText(children)
                .font(.system(size: 18, weight: .semibold))
                .padding(.vertical, 2)

        case "h4":
            inlineText(children)
                .font(.system(size: 16, weight: .semibold))
                .padding(.vertical, 2)

        case "h5", "h6":
            inlineText(children)
                .font(.system(size: 14, weight: .semibold))
                .padding(.vertical, 2)

        case "blockquote":
            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 3)
                    .cornerRadius(1.5)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        HTMLNodeView(node: child, context: .block)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 10)
            }
            .padding(.vertical, 4)

        case "pre":
            ScrollView(.horizontal, showsIndicators: false) {
                inlineText(children)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)

        case "code":
            // Block code vs inline code
            if case .block = context {
                inlineText(children)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            } else {
                inlineText(children)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            }

        case "hr":
            Divider()
                .padding(.vertical, 8)

        case "br":
            Text(" ")

        // MARK: Lists
        case "ul":
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    if case .element(let t, let a, let c) = child, t == "li" {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.accentColor)
                                .frame(minWidth: 12, alignment: .leading)
                            inlineText(c)
                        }
                    } else {
                        HTMLNodeView(node: child, context: .block)
                    }
                }
            }
            .padding(.leading, 4)

        case "ol":
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(liItems(children).enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .foregroundColor(.accentColor)
                            .frame(minWidth: 20, alignment: .trailing)
                        inlineText(item)
                    }
                }
            }
            .padding(.leading, 4)

        case "li":
            inlineText(children)

        // MARK: Tables
        case "table":
            tableView(children)

        // MARK: Div / Section / Article / etc.
        case "div", "section", "article", "main", "header", "footer", "nav", "aside", "figure", "figcaption":
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    HTMLNodeView(node: child, context: .block)
                }
            }

        // MARK: Inline elements — rendered as attributed Text
        case "strong", "b", "em", "i", "u", "s", "del", "mark", "small", "span", "a":
            inlineText([.element(tag: tag, attributes: attributes, children: children)])

        case "sup":
            inlineText([.element(tag: tag, attributes: attributes, children: children)])

        case "sub":
            inlineText([.element(tag: tag, attributes: attributes, children: children)])

        // MARK: Images
        case "img":
            if let src = attributes["src"], let url = URL(string: src) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .overlay(ProgressView())
                }
            }

        default:
            // Fallback: render children
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    HTMLNodeView(node: child, context: .block)
                }
            }
        }
    }

    // MARK: - Inline AttributedText Builder

    private func inlineText(_ nodes: [HTMLNode]) -> Text {
        nodes.reduce(Text("")) { result, node in
            result + textFrom(node: node, bold: false, italic: false, underline: false, strikethrough: false, link: nil, color: nil, mark: false, small: false, superscript: false, subscript_: false)
        }
    }

    private func textFrom(
        node: HTMLNode,
        bold: Bool,
        italic: Bool,
        underline: Bool,
        strikethrough: Bool,
        link: String?,
        color: Color?,
        mark: Bool,
        small: Bool,
        superscript: Bool,
        subscript_: Bool
    ) -> Text {
        switch node {
        case .text(let string):
            var t = Text(string)
            if bold { t = t.bold() }
            if italic { t = t.italic() }
            if underline { t = t.underline() }
            if strikethrough { t = t.strikethrough() }
            if small { t = t.font(.caption) }
            if let c = color { t = t.foregroundColor(c) }
            if link != nil { t = t.foregroundColor(.accentColor).underline() }
            if superscript { t = t.font(.system(size: 11)).baselineOffset(6) }
            if subscript_ { t = t.font(.system(size: 11)).baselineOffset(-4) }
            return t

        case .element(let tag, let attrs, let children):
            let nextBold = bold || tag == "strong" || tag == "b"
            let nextItalic = italic || tag == "em" || tag == "i"
            let nextUnderline = underline || tag == "u"
            let nextStrike = strikethrough || tag == "s" || tag == "del"
            let nextLink = link ?? attrs["href"]
            let nextColor: Color? = tag == "mark" ? .yellow : (tag == "a" ? .accentColor : color)
            let nextSmall = small || tag == "small"
            let nextSuperscript = superscript || tag == "sup"
            let nextSubscript = subscript_ || tag == "sub"

            // code inline
            if tag == "code" {
                let raw = children.reduce("") {
                    if case .text(let s) = $1 { return $0 + s }
                    return $0
                }
                return Text(raw)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.orange)
            }

            return children.reduce(Text("")) { result, child in
                result + textFrom(
                    node: child,
                    bold: nextBold,
                    italic: nextItalic,
                    underline: nextUnderline,
                    strikethrough: nextStrike,
                    link: nextLink,
                    color: nextColor,
                    mark: tag == "mark",
                    small: nextSmall,
                    superscript: nextSuperscript,
                    subscript_: nextSubscript
                )
            }
        }
    }

    // MARK: - Helpers

    private func liItems(_ nodes: [HTMLNode]) -> [[HTMLNode]] {
        nodes.compactMap { node -> [HTMLNode]? in
            if case .element(let tag, _, let children) = node, tag == "li" {
                return children
            }
            return nil
        }
    }

    // MARK: - Table

    @ViewBuilder
    private func tableView(_ nodes: [HTMLNode]) -> some View {
        let rows = extractTableRows(nodes)
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, cells in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(cells.enumerated()), id: \.offset) { colIdx, cell in
                            let isHeader = cell.isHeader
                            inlineText(cell.children)
                                .font(isHeader ? .headline : .body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(isHeader ? Color.accentColor.opacity(0.15) : (rowIdx % 2 == 0 ? Color(.systemBackground) : Color(.systemGray6)))
                                .overlay(
                                    Rectangle().stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
            .clipped()
        }
    }

    private struct TableCell {
        let children: [HTMLNode]
        let isHeader: Bool
    }

    private func extractTableRows(_ nodes: [HTMLNode]) -> [[TableCell]] {
        var rows: [[TableCell]] = []
        for node in nodes {
            if case .element(let tag, _, let children) = node {
                if tag == "tr" {
                    let cells = children.compactMap { cellNode -> TableCell? in
                        if case .element(let ct, _, let cc) = cellNode, (ct == "td" || ct == "th") {
                            return TableCell(children: cc, isHeader: ct == "th")
                        }
                        return nil
                    }
                    if !cells.isEmpty { rows.append(cells) }
                } else {
                    rows.append(contentsOf: extractTableRows(children))
                }
            }
        }
        return rows
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        HTMLView(html: """
        <h1>HTMLView Demo</h1>
        <p>This view <strong>parses</strong> and renders <em>HTML strings</em> natively in SwiftUI.</p>
        <h2>Superscript &amp; Subscript</h2>
        <p>E = mc<sup>2</sup> and H<sub>2</sub>O are classic examples.</p>
        <p>Footnote reference<sup>1</sup> and chemical formula CO<sub>2</sub>.</p>
        <h2>Text Formatting</h2>
        <p>You can use <strong>bold</strong>, <em>italic</em>, <u>underline</u>, <s>strikethrough</s>, and <code>inline code</code>.</p>
        <p>Links look like <a href="https://apple.com">this</a>, and <mark>highlights</mark> too.</p>
        <h2>Unordered List</h2>
        <ul>
          <li>SwiftUI</li>
          <li>UIKit</li>
          <li>AppKit</li>
        </ul>
        <h2>Ordered List</h2>
        <ol>
          <li>Parse HTML string</li>
          <li>Build node tree</li>
          <li>Render with SwiftUI</li>
        </ol>
        <h2>Blockquote</h2>
        <blockquote><p>Design is not just what it looks like. Design is how it works.</p></blockquote>
        <h2>Code Block</h2>
        <pre>let view = HTMLView(html: "&lt;p&gt;Hello&lt;/p&gt;")</pre>
        <h2>Table</h2>
        <table>
          <tr><th>Name</th><th>Type</th><th>Support</th></tr>
          <tr><td>p</td><td>Block</td><td>✅</td></tr>
          <tr><td>ul / ol</td><td>List</td><td>✅</td></tr>
          <tr><td>table</td><td>Table</td><td>✅</td></tr>
          <tr><td>a</td><td>Inline</td><td>✅</td></tr>
        </table>
        <hr/>
        <p><small>Built with a pure Swift HTML parser — no WebView needed.</small></p>
        """)
        .padding()
    }
}
