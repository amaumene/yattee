import SwiftUI

struct StreamControl: View {
    @Binding var presentingButtonHintAlert: Bool

    @EnvironmentObject<PlayerModel> private var player

    init(presentingButtonHintAlert: Binding<Bool> = .constant(false)) {
        _presentingButtonHintAlert = presentingButtonHintAlert
    }

    var body: some View {
        Group {
            #if os(macOS)
                Picker("", selection: $player.streamSelection) {
                    ForEach(InstancesModel.all) { instance in
                        let instanceStreams = availableStreamsForInstance(instance)
                        if !instanceStreams.values.isEmpty {
                            let kinds = Array(instanceStreams.keys).sorted { $0 < $1 }

                            Section(header: Text(instance.longDescription)) {
                                ForEach(kinds, id: \.self) { key in
                                    ForEach(instanceStreams[key] ?? []) { stream in
                                        Text(stream.description).tag(Stream?.some(stream))
                                    }

                                    if kinds.count > 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .disabled(player.isLoadingAvailableStreams)

            #elseif os(iOS)
                Picker("", selection: $player.streamSelection) {
                    ForEach(InstancesModel.all) { instance in
                        let instanceStreams = availableStreamsForInstance(instance)
                        if !instanceStreams.values.isEmpty {
                            let kinds = Array(instanceStreams.keys).sorted { $0 < $1 }

                            ForEach(kinds, id: \.self) { key in
                                ForEach(instanceStreams[key] ?? []) { stream in
                                    Text(stream.description).tag(Stream?.some(stream))
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 110)
                .fixedSize(horizontal: true, vertical: true)
                .disabled(player.isLoadingAvailableStreams)
            #else
                Button {
                    presentingButtonHintAlert = true
                } label: {
                    Text(player.streamSelection?.shortQuality ?? "loading")
                        .frame(maxWidth: 320)
                }
                .contextMenu {
                    ForEach(streams) { stream in
                        Button(stream.description) { player.streamSelection = stream }
                    }

                    Button("Close", role: .cancel) {}
                }
            #endif
        }

        .transaction { t in t.animation = .none }
        .onChange(of: player.streamSelection) { selection in
            guard let selection = selection else { return }
            player.upgradeToStream(selection)
            player.controls.hideOverlays()
        }
        .frame(alignment: .trailing)
    }

    private func availableStreamsForInstance(_ instance: Instance) -> [Stream.Kind: [Stream]] {
        let streams = streams.filter { $0.instance == instance }.filter { player.backend.canPlay($0) }

        return Dictionary(grouping: streams, by: \.kind!)
    }

    var streams: [Stream] {
        player.availableStreamsSorted.filter { player.backend.canPlay($0) }
    }
}

struct StreamControl_Previews: PreviewProvider {
    static var previews: some View {
        StreamControl()
            .injectFixtureEnvironmentObjects()
    }
}
