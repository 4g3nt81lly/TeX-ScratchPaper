//
//  ConfigView.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/6.
//

import SwiftUI

/// SwiftUI view for the configuration view.
struct ConfigView: View {
    
    /**
     Observed reference to a configuration object to be modified.
     
     `ConfigView` makes changes to a configuration object via this reference.
     */
    @ObservedObject var config: Configuration
    
    /**
     An unowned reference to the editor view from which the `ConfigView` instance is presented.
     
     This reference is used to interact with the editor view.
     
     - Note: It does NOT retain the editor view object.
     */
    unowned var editor: Editor!
    
    /**
     Set this state property to `true` to notify `ConfigView` of user's request to save current configuration as the app's default configuration, which subsequently displays a confirmation alert.
     
     This property should not be changed unless the user clicks on the icon well.
     */
    @State private var saveAsDefaultAlert = false
    
    var body: some View {
        VStack {
            List {
                // MARK: Live Render
                GroupBox {
                    HStack {
                        Image(systemName: "livephoto.badge.a")
                            .font(.system(size: 20))
                            .padding(2)
                        Toggle(isOn: $config.liveRender) {
                            Text("Live Render")
                            Text("Enables live rendering as you type. It may be memory-heavy with large files.")
                                .font(.system(.caption))
                        }
                        .toggleStyle(.switch)
                        .padding(.bottom, 3)
                    }
                    .padding(5)
                }
                // MARK: Rendering
                GroupBox {
                    // Render Error
                    Group {
                        HStack {
                            Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
                                .font(.system(size: 20))
                                .padding(2)
                            Toggle(isOn: $config.renderError) {
                                Text("Render Error")
                                Text("Renders invalid LaTeX syntax or unknown commands as color-coded texts.")
                                    .font(.system(.caption))
                            }
                            .toggleStyle(.switch)
                        }
                        .padding(EdgeInsets(top: 5, leading: 5, bottom: 0, trailing: 5))
                        if config.renderError {
                            ColorPicker("Error Color", selection: $config.errorColor)
                                .padding(.leading, 10)
                                .padding(.bottom, -5)
                        }
                        Divider().padding(EdgeInsets(top: 5, leading: 3, bottom: 3, trailing: 3))
                    }
                    // Minimum Line Thickness
                    Group {
                        HStack(alignment: .top) {
                            Image(systemName: "lineweight")
                                .font(.system(size: 20))
                                .padding(2)
                                .padding(.top, 10)
                            Toggle(isOn: $config.minLineThicknessEnabled) {
                                Text("Minimum Line Thickness")
                                Text(#"Fraction lines, '\sqrt' top lines, '{array}' vertical lines, '\hline', '\hdashline', '\underline', '\overline', and borders of '\fbox', '\boxed', and '\fcolorbox'."#)
                                    .font(.system(.caption))
                            }
                            .toggleStyle(.switch)
                        }
                        .padding(.horizontal, 5)
                        if config.minLineThicknessEnabled {
                            HStack {
                                Slider(value: $config.minLineThickness, in: 0...0.5)
                                    .frame(alignment: .leading)
                                Text("\(String(format: "%.2f", config.minLineThickness)) em")
                                    .frame(width: 50, alignment: .trailing)
                                    .padding(.trailing, 5)
                            }
                            .padding(.bottom, -3)
                        }
                        Divider().padding(EdgeInsets(top: 5, leading: 3, bottom: 3, trailing: 3))
                    }
                    // Left Justify Tags (leqno)
                    Group {
                        HStack {
                            Image(systemName: "arrow.left.to.line.circle.fill")
                                .font(.system(size: 20))
                                .padding(2)
                            Toggle(isOn: $config.leftJustifyTags) {
                                Text("Left Justify Tags (leqno)")
                                Text(#"Renders '\tag's to the left instead of right."#)
                                    .font(.system(.caption))
                            }
                            .toggleStyle(.switch)
                        }
                        .padding(.horizontal, 5)
                        Divider().padding(EdgeInsets(top: 5, leading: 3, bottom: 3, trailing: 3))
                    }
                    // Size Limit
                    Group {
                        HStack {
                            Image(systemName: "textformat.size")
                                .font(.system(size: 17))
                                .padding(2)
                            Toggle(isOn: $config.sizeLimitEnabled) {
                                Text("Size Limit")
                                Text(#"Limits user-specified sizes for elements and spaces."#)
                                    .font(.system(.caption))
                            }
                            .toggleStyle(.switch)
                        }
                        .padding(EdgeInsets(top: 0, leading: 5, bottom: 10, trailing: 5))
                        if config.sizeLimitEnabled {
                            HStack {
                                Text("Maximum Size")
                                    .padding(.leading, 10)
                                Spacer()
                                Stepper(value: $config.sizeLimit, in: 0.01...(.infinity), step: 1) {
                                    TextField("", value: $config.sizeLimit, formatter: config.sizeLimitFormatter)
                                        .textFieldStyle(.squareBorder)
                                        .padding(.trailing, -3)
                                        .frame(minWidth: 30, maxWidth: 90)
                                        .fixedSize()
                                }
                                .fixedSize()
                                Text("em")
                                    .padding(.trailing, 10)
                            }
                            .padding(EdgeInsets(top: -10, leading: 0, bottom: 5, trailing: 0))
                        }
                        // Divider().padding(EdgeInsets(top: 5, leading: 3, bottom: 3, trailing: 3))
                    }
                } label: {
                    Text("Rendering")
                        .font(.system(.headline))
                        .fontWeight(.semibold)
                        .padding(.bottom, 5)
                }
                .padding(.top, 3)
                // MARK: Security
                GroupBox {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 20))
                                .padding(2)
                            Toggle(isOn: $config.trustAllCommands) {
                                Text("Trust Commands")
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Trust and allow the use of following commands.")
                                    .fixedSize(horizontal: false, vertical: true)
                                    .font(.system(.caption))
                            }
                            .toggleStyle(.switch)
                            .padding(.bottom, 3)
                        }
                        ForEach($config.trustedCommands) { item in
                            Toggle(isOn: item.trusted) {
                                Text("Trust \(item.name.wrappedValue)")
                                    .font(.system(size: 12))
                            }
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        }
                        .padding(EdgeInsets(top: 0, leading: 5, bottom: 5, trailing: 5))
                        Text("The input to these commands are not trusted and disabled by default to prevent causing adverse behavior, therefore they are rendered as error unless trusted.")
                            .fixedSize(horizontal: false, vertical: true)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 5)
                    }
                    .padding(5)
                    Divider().padding(EdgeInsets(top: 5, leading: 3, bottom: 5, trailing: 3))
                    HStack(alignment: .top) {
                        Image(systemName: "lock.rotation.open")
                            .font(.system(size: 20))
                            .padding(2)
                            .padding(.top, 10)
                        Toggle(isOn: $config.maxExpansionEnabled) {
                            Text("Limit Macro Expansion")
                            Text("Limits the number of macro expansions to prevent, for instance, infinite macro loop attacks.")
                                .font(.system(.caption))
                        }
                        .toggleStyle(.switch)
                        .padding(.bottom, 3)
                    }
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 10, trailing: 5))
                    if config.maxExpansionEnabled {
                        HStack {
                            Text("Maximum No.")
                            Spacer()
                            Stepper(value: $config.maxExpansion, in: 1...(.infinity), step: 1) {
                                TextField("", value: $config.maxExpansion, formatter: config.maxExpansionFormatter)
                                    .textFieldStyle(.squareBorder)
                                    .padding(.trailing, -3)
                                    .frame(minWidth: 40, maxWidth: 60)
                                    .fixedSize()
                            }
                            .fixedSize()
                        }
                        .padding(EdgeInsets(top: -15, leading: 10, bottom: 10, trailing: 5))
                    }
                } label: {
                    Text("Security")
                        .font(.system(.headline))
                        .fontWeight(.semibold)
                        .padding(.bottom, 5)
                }
                .padding(.top, 3)
            }
            .frame(minWidth: 500, idealWidth: 550, minHeight: 400)
            .cornerRadius(10)
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 10))
            HStack(spacing: 10) {
                Button {
                    self.editor.dismissConfigView()
                } label: {
                    Text("Cancel")
                        .frame(width: 55)
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    saveAsDefaultAlert = true
                } label: {
                    Text("Save As Default")
                        .frame(width: 100)
                }
                Button {
                    self.editor.dismissConfigView(updateConfig: true)
                } label: {
                    Text("Done")
                        .frame(width: 50)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(EdgeInsets(top: 5, leading: 20, bottom: 20, trailing: 20))
        }
        .frame(maxWidth: 1000, maxHeight: 700)
        .alert(isPresented: $saveAsDefaultAlert) {
            Alert(title: Text("Save As Default"), message: Text("Are you sure you want to save the configuration as default?"), primaryButton: .default(Text("Yes"), action: {
                self.config.saveToSettings()
            }), secondaryButton: .cancel(Text("No")))
        }
    }
    
}
