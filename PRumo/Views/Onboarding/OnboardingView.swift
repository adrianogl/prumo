import SwiftUI
import AppKit

struct OnboardingView: View {
    @State private var flow: OnboardingModel
    @Environment(\.dismissWindow) private var dismissWindow

    init(app: AppModel) {
        _flow = State(initialValue: OnboardingModel(app: app))
    }

    var body: some View {
        VStack {
            switch flow.step {
            case .welcome: welcome
            case .token: token
            case .notifications: notifications
            case .ready: ready
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(width: OnboardingMetrics.width)
        .background(Color.prumoPopoverBackground)
        .task { await flow.detectGh() }
    }

    private var welcome: some View {
        VStack(spacing: 4) {
            Image(PopoverSymbol.appLogo)
                .resizable()
                .interpolation(.high)
                .frame(width: OnboardingMetrics.iconSize, height: OnboardingMetrics.iconSize)
            Wordmark(size: 28).padding(.top, 4)
            Text(OnboardingText.tagline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
            if flow.isCheckingGh {
                ProgressView(OnboardingText.checking).controlSize(.small)
            } else if let login = flow.ghLogin {
                Label(OnboardingText.foundGh(login), systemImage: OnboardingSymbol.found)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Button(OnboardingText.useThisAccount, action: flow.useGh)
                        .buttonStyle(PrimaryButtonStyle())
                    Button(OnboardingText.useOtherToken, action: flow.useOtherToken)
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 10)
                errorLine
            } else {
                errorLine
                Button(OnboardingText.useToken, action: flow.useOtherToken)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
            }
        }
    }

    private var token: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(OnboardingText.tokenPrompt)
            SecureField(OnboardingText.tokenPlaceholder, text: $flow.tokenInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await flow.connectPasted() } }
            Text(.init("\(OnboardingText.scopes) [\(OnboardingText.createToken)](\(AppConstants.tokenCreationURL.absoluteString))"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if let message = flow.errorMessage {
                Text(message).font(.system(size: 12)).foregroundStyle(.red)
            }
            HStack(spacing: 8) {
                Spacer()
                if flow.isValidating { ProgressView().controlSize(.small) }
                Button(OnboardingText.back) {
                    flow.errorMessage = nil
                    flow.step = .welcome
                }
                .buttonStyle(SecondaryButtonStyle())
                Button(OnboardingText.connect) { Task { await flow.connectPasted() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(flow.isValidating || flow.tokenInput.isEmpty)
            }
            .padding(.top, 8)
        }
    }

    private var notifications: some View {
        VStack(spacing: 8) {
            Image(systemName: OnboardingSymbol.notifications)
                .font(.system(size: 34))
                .foregroundStyle(Color.prumoCaramel)
            Text(OnboardingText.notificationsTitle).font(.system(size: 16, weight: .semibold))
            Text(OnboardingText.notificationsBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Button(OnboardingText.skip, action: flow.enterReady)
                    .buttonStyle(SecondaryButtonStyle())
                Button(OnboardingText.allowNotifications) { Task { await flow.requestNotifications() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.top, 8)
        }
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(OnboardingText.readyTitle).font(.system(size: 16, weight: .semibold))
            Toggle(OnboardingText.launchAtLogin, isOn: $flow.launchAtLogin)
                .onChange(of: flow.launchAtLogin) { flow.applyLaunchAtLogin() }
            if let error = flow.launchError {
                Text(error).font(.system(size: 12)).foregroundStyle(.red)
            }
            Text(OnboardingText.readyNote)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(OnboardingText.start) { dismissWindow(id: OnboardingText.id) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var errorLine: some View {
        if let message = flow.errorMessage {
            Text(message).font(.system(size: 12)).foregroundStyle(.red).padding(.top, 6)
        }
    }
}
