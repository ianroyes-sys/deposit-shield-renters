import SwiftUI

/// Ports new-property-form.tsx — a 4-step native form (Address, Deposit &
/// lease, Landlord, Rooms) ending in a Supabase insert.
struct NewPropertyView: View {
    @Binding var path: [AppRoute]

    private let steps = ["Address", "Deposit & lease", "Landlord", "Rooms"]
    @State private var step = 0
    @State private var error: String?
    @State private var creating = false

    @State private var nickname = ""
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var depositDollars = ""
    @State private var leaseStart = Date()
    @State private var hasLeaseStart = false
    @State private var landlordName = ""
    @State private var landlordEmail = ""
    @State private var rooms: [String] = DEFAULT_ROOM_NAMES
    @State private var newRoomName = ""

    private var selectedLaw: StateDepositLaw? { StateDepositLaws.law(for: state) }

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    stepIndicator

                    LedgerCard {
                        Group {
                            switch step {
                            case 0: addressStep
                            case 1: depositStep
                            case 2: landlordStep
                            default: roomsStep
                            }
                        }

                        if let error {
                            Text(error).font(.system(size: 13)).foregroundStyle(DS.clay).padding(.top, 12)
                        }

                        HStack {
                            Button {
                                Haptics.tap()
                                error = nil
                                step = max(0, step - 1)
                            } label: {
                                Text("Back").font(.system(size: 14, weight: .medium)).foregroundStyle(DS.ink.opacity(step == 0 ? 0.25 : 0.6))
                            }
                            .buttonStyle(.plain)
                            .disabled(step == 0)

                            Spacer()

                            if step < steps.count - 1 {
                                Button {
                                    Haptics.tap()
                                    advance()
                                } label: {
                                    Text("Continue").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 20).padding(.vertical, 11)
                                        .background(DS.emerald, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    Haptics.tap()
                                    submit()
                                } label: {
                                    HStack(spacing: 6) {
                                        if creating { ProgressView().tint(.white).scaleEffect(0.8) }
                                        Text(creating ? "Creating\u{2026}" : "Create property")
                                    }
                                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                    .padding(.horizontal, 20).padding(.vertical, 11)
                                    .background(DS.emerald, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(creating)
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("New property")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, label in
                VStack(spacing: 6) {
                    Capsule().fill(i <= step ? DS.emerald : DS.ink.opacity(0.1)).frame(height: 4)
                    Text(label).font(.system(size: 10.5, weight: .medium)).foregroundStyle(i == step ? DS.ink : DS.ink.opacity(0.35))
                }
            }
        }
    }

    // MARK: Step 0

    private var addressStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledField(label: "Nickname (optional)") {
                TextField("e.g. The Elmwood apartment", text: $nickname).ledgerFieldStyle()
            }
            LabeledField(label: "Street address") {
                TextField("123 Main St", text: $addressLine1).ledgerFieldStyle()
            }
            LabeledField(label: "Apt / unit (optional)") {
                TextField("Apt 4B", text: $addressLine2).ledgerFieldStyle()
            }
            HStack(spacing: 12) {
                LabeledField(label: "City") { TextField("", text: $city).ledgerFieldStyle() }
                LabeledField(label: "ZIP") { TextField("", text: $zip).keyboardType(.numberPad).ledgerFieldStyle() }
                    .frame(width: 100)
            }
            LabeledField(label: "State") {
                Picker("State", selection: $state) {
                    Text("Select a state").tag("")
                    ForEach(StateDepositLaws.all) { law in
                        Text(law.name).tag(law.code)
                    }
                }
                .pickerStyle(.menu)
                .ledgerFieldStyle()
            }
            if let law = selectedLaw {
                InlineNotice(text: "In \(law.name), landlords generally must return your deposit within \(law.returnDeadlineDays) days. Not legal advice \u{2014} verify with your state.")
            }
        }
    }

    // MARK: Step 1

    private var depositStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledField(label: "Deposit amount (USD)") {
                TextField("1500", text: $depositDollars).keyboardType(.decimalPad).ledgerFieldStyle()
            }
            LabeledField(label: "Lease start date") {
                Toggle(isOn: $hasLeaseStart.animation()) {
                    Text("Set a lease start date").font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.7))
                }
                .tint(DS.emerald)
                if hasLeaseStart {
                    DatePicker("", selection: $leaseStart, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: Step 2

    private var landlordStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledField(label: "Landlord / property manager name") {
                TextField("", text: $landlordName).ledgerFieldStyle()
            }
            LabeledField(label: "Landlord email") {
                TextField("landlord@example.com", text: $landlordEmail)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never).ledgerFieldStyle()
            }
            Text("Used later if you choose to send your condition report directly to your landlord.")
                .font(.system(size: 12)).foregroundStyle(DS.ink.opacity(0.45))
        }
    }

    // MARK: Step 3

    private var roomsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Edit, remove, or add rooms you'll photograph.")
                .font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.6))
            ForEach(rooms.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    TextField("", text: Binding(get: { rooms[i] }, set: { rooms[i] = $0 })).ledgerFieldStyle()
                    Button {
                        Haptics.tap()
                        rooms.remove(at: i)
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(DS.ink.opacity(0.4))
                            .padding(10).background(DS.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                TextField("Add a room (e.g. Garage)", text: $newRoomName)
                    .ledgerFieldStyle()
                    .onSubmit { addRoom() }
                Button("Add") { addRoom() }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.emeraldDark)
            }
            .padding(.top, 4)
        }
    }

    private func addRoom() {
        let trimmed = newRoomName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        rooms.append(trimmed)
        newRoomName = ""
    }

    private func advance() {
        error = nil
        if step == 0 && addressLine1.trimmingCharacters(in: .whitespaces).isEmpty {
            error = "Add at least a street address."
            return
        }
        step = min(step + 1, steps.count - 1)
    }

    private func submit() {
        error = nil
        creating = true
        Task {
            do {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                df.timeZone = TimeZone(identifier: "UTC")

                let input = DataStore.NewPropertyInput(
                    nickname: nickname,
                    addressLine1: addressLine1,
                    addressLine2: addressLine2,
                    city: city,
                    state: state,
                    zip: zip,
                    depositAmountDollars: depositDollars,
                    leaseStart: hasLeaseStart ? df.string(from: leaseStart) : "",
                    landlordName: landlordName,
                    landlordEmail: landlordEmail,
                    rooms: rooms
                )
                let property = try await DataStore.createProperty(input)
                await MainActor.run {
                    creating = false
                    path = [.property(property.id)]
                }
            } catch {
                await MainActor.run {
                    creating = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
            content
        }
    }
}

extension View {
    func ledgerFieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(DS.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DS.ink.opacity(0.1)))
            .font(.system(size: 14))
    }
}
