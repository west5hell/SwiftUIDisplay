//
//  ContentView.swift
//  SwiftUIDisplay
//
//  Created by Pongt Chia on 26/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
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
}

#Preview {
    ContentView()
}
