//
//  TemplatesView.swift
//  T2C
//
//  Input text templates management view
//

import SwiftUI

struct TemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var templates: [TemplateService.InputTemplate] = []
    @State private var showNewTemplate = false

    let onSelectTemplate: (TemplateService.InputTemplate) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "templates.empty.title"), systemImage: "doc.on.doc")
                    } description: {
                        Text(String(localized: "templates.empty.description"))
                    } actions: {
                        VStack(spacing: 12) {
                            Button(String(localized: "templates.add")) {
                                showNewTemplate = true
                            }
                            .buttonStyle(.borderedProminent)

                            Button(String(localized: "templates.load_samples")) {
                                loadSampleTemplates()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    List {
                        ForEach(templates) { template in
                            Button {
                                onSelectTemplate(template)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Template name
                                    Text(template.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)

                                    // Template text preview
                                    Text(template.text)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteTemplates)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(String(localized: "templates.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "templates.close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showNewTemplate = true
                        } label: {
                            Label(String(localized: "templates.add"), systemImage: "plus")
                        }

                        Divider()

                        Button {
                            loadSampleTemplates()
                        } label: {
                            Label(String(localized: "templates.load_samples"), systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showNewTemplate) {
                NewTemplateView { newTemplate in
                    TemplateService.shared.addTemplate(newTemplate)
                    templates = TemplateService.shared.templates
                }
            }
            .onAppear {
                templates = TemplateService.shared.templates
            }
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            TemplateService.shared.deleteTemplate(id: templates[index].id)
        }
        templates = TemplateService.shared.templates
    }

    private func loadSampleTemplates() {
        TemplateService.shared.resetToDefaults()
        templates = TemplateService.shared.templates
    }
}

struct NewTemplateView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var text: String = ""

    let onSave: (TemplateService.InputTemplate) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "templates.new.name"), text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text(String(localized: "templates.new.section.name"))
                } footer: {
                    Text(String(localized: "templates.new.name.footer"))
                }

                Section {
                    TextField(String(localized: "templates.new.text"), text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text(String(localized: "templates.new.section.text"))
                } footer: {
                    Text(String(localized: "templates.new.text.footer"))
                }
            }
            .navigationTitle(String(localized: "templates.new.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "templates.new.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "templates.new.save")) {
                        let template = TemplateService.InputTemplate(
                            name: name,
                            text: text
                        )
                        onSave(template)
                        dismiss()
                    }
                    .disabled(name.isEmpty || text.isEmpty)
                }
            }
        }
    }
}

#Preview {
    TemplatesView { _ in }
}
