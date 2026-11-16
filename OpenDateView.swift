import SwiftUI
import UserNotifications
import MapKit
import PhotosUI
import CoreLocation

struct OpenDateView: View {
    private let plum = Color(red:0.22, green:0.10, blue:0.17)
    private let rose = Color(red:0.64, green:0.18, blue:0.31)
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var room = NearbyRoom()
    @State private var roomOnly = false
    @State private var floorCode = ""
    @State private var building = DemoBuilding.exchange
    @State private var currentRoom = 0
    @State private var demo = true
    @State private var open = true
    @State private var analyzing = false
    @State private var finishedScan = false
    @State private var instant = false
    @State private var dismissed: Set<UUID> = []
    @State private var alerted: Set<UUID> = []
    @State private var banner: DateProfile?
    @State private var selected: DateProfile?
    @State private var editing = false
    @State private var detail: DateProfile?
    @State private var likes: Set<UUID> = []
    @State private var liveSaved: [DateProfile] = {
        guard let data=UserDefaults.standard.data(forKey:"openDate.matches") else {return []}
        return (try? JSONDecoder().decode([DateProfile].self,from:data))?.filter { !DateProfile.examples.map(\.id).contains($0.id) } ?? []
    }()
    @State private var demoSaved = [DateProfile.examples[1], DemoCrowd.people[3]]
    @State private var demoProfile = DateProfile(name:"Elena", interests:["Design","Music"], lookingFor:"Someone to explore with", occupation:"Graphic designer", education:"BFA in Visual Communication", personality:"I design album covers and spend Sundays digging through used records.", symbol:"sun.max.fill")
    @State private var demoSelfNote = "My favorite part of a concert is the walk home talking about the set. I’d love to meet someone who wants to trade playlists and try a new venue."
    @AppStorage("openDate.idealPartner") private var idealPartner = ""
    @State private var demoIdealPartner = "Someone curious and kind who asks follow-up questions, follows through on plans, and can laugh with me when we miss the opening act."
    @State private var demoIdealDate = "An early set at a small jazz club, then a walk somewhere quiet so we can talk about our favorite song."
    @AppStorage("openDate.idealDate") private var idealDate = ""
    @State private var demoPortrait = "You enjoy music as a way to get to know someone. A small show with time to talk afterward sounds like your kind of first date."
    @State private var demoMeetingNote = "Remy and I got talking about record shops. We traded favorite albums, and I wanted the conversation to keep going. I’d like to invite them to Sunday's record fair."
    @State private var demoMeetingReflection = "You felt at ease once you had a shared subject. The record fair gives you a specific reason to reconnect. Would you enjoy browsing together even if you came home empty-handed?"
    private var saved: [DateProfile] { demo ? demoSaved : liveSaved }
    private var profileBinding: Binding<DateProfile> { demo ? $demoProfile : $liveProfile }
    private var profile: DateProfile { profileBinding.wrappedValue }
    @State private var tab = UserDefaults.standard.object(forKey: "uiShotTab") as? Int ?? 3
    @State private var drag: CGSize = .zero
    @State private var likeCount = 0
    @State private var matchMoment: DateProfile? = UserDefaults.standard.bool(forKey: "uiShotMatch") ? DateProfile.examples[2] : nil
    init() {
        if let d = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.rounded)?.withSymbolicTraits(.traitBold) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont(descriptor: d, size: 34)]
        }
    }
    private func chemistry(_ p: DateProfile) -> Int {
        if !demo, let s = exchanges[p.id]?.score { return Int((s * 100).rounded()) }
        let total = max(1, max(profile.interests.count, p.interests.count))
        let ratio = Double(common(p).count) / Double(total)
        let jitter = Double(p.id.uuidString.utf8.reduce(0) { ($0 + Int($1)) % 9 })
        return min(98, Int((58 + 30 * ratio + (profile.lookingFor == p.lookingFor ? 8 : 0) + jitter).rounded()))
    }
    private var deckPeople: [DateProfile] {
        let pool = nearby.map(\.profile).filter { p in !likes.contains(p.id) && !saved.contains { $0.id == p.id } }
        let sharp = demo ? pool.filter { PortraitStore.hasHD($0) } : []
        return sharp.isEmpty ? pool : sharp
    }
    private func swipe(_ p: DateProfile, liked: Bool) {
        UIImpactFeedbackGenerator(style: liked ? .medium : .light).impactOccurred()
        withAnimation(.easeIn(duration: 0.22)) { drag = CGSize(width: liked ? 620 : -620, height: drag.height + 30) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) {
            drag = .zero
            if liked { deckLike(p) } else { skip(p) }
        }
    }
    private func deckLike(_ p: DateProfile) {
        likeCount += 1
        // Demo: every second like is mutual. Live: a match needs the other phone's like.
        if demo && !likeCount.isMultiple(of: 2) { likes.insert(p.id); return }
        let known = saved.contains { $0.id == p.id }
        like(p)
        if !known && (demo || room.incoming.contains(p.id)) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(duration: 0.4)) { matchMoment = p }
        }
    }
    private func stamp(_ text: String, _ color: Color, angle: Double) -> some View {
        Text(text).font(.system(size: 40, weight: .heavy, design: .rounded)).tracking(2)
            .foregroundStyle(color).padding(.horizontal, 14).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color, lineWidth: 4))
            .rotationEffect(.degrees(angle)).padding(26)
    }
    private func roundButton(_ icon: String, _ color: Color, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(color)
                .frame(width: size, height: size).background(.white, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }.buttonStyle(.plain)
    }
    private var deck: some View {
        let people = deckPeople
        return NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "heart.circle.fill").foregroundStyle(rose)
                    Text("open date").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(rose)
                    Spacer()
                    NavigationLink { discovery.navigationBarTitleDisplayMode(.inline) } label: {
                        Image(systemName: "map").font(.title3.weight(.semibold)).foregroundStyle(plum.opacity(0.7))
                    }.accessibilityLabel("Nearby map")
                }.padding(.horizontal, 6)
                ZStack {
                    if people.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "heart.circle.fill").font(.system(size: 64)).foregroundStyle(rose.opacity(0.35))
                            Text("That's everyone nearby").font(.system(.title3, design: .rounded).weight(.semibold)).foregroundStyle(plum)
                            Button("Start over") { dismissed = []; likes = [] }.buttonStyle(.bordered).tint(rose)
                        }
                    }
                    ForEach(Array(people.prefix(2).enumerated()).reversed(), id: \.element.id) { i, p in
                        DeckCard(person: p, chemistry: chemistry(p), showAge: demo)
                            .overlay(alignment: .topLeading) { if i == 0 { stamp("LIKE", .green, angle: -14).opacity(Double(max(0, min(1, drag.width / 90)))) } }
                            .overlay(alignment: .topTrailing) { if i == 0 { stamp("NOPE", .red, angle: 14).opacity(Double(max(0, min(1, -drag.width / 90)))) } }
                            .scaleEffect(i == 0 ? 1 : 0.95)
                            .offset(i == 0 ? drag : CGSize(width: 0, height: 10))
                            .rotationEffect(.degrees(i == 0 ? Double(drag.width) / 18 : 0))
                            .allowsHitTesting(i == 0)
                            .gesture(DragGesture()
                                .onChanged { drag = $0.translation }
                                .onEnded { v in
                                    if abs(v.translation.width) > 110 || abs(v.predictedEndTranslation.width) > 320 { swipe(p, liked: v.translation.width > 0) }
                                    else { withAnimation(.spring(duration: 0.3)) { drag = .zero } }
                                })
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 44) {
                    roundButton("xmark", Color(.systemGray), size: 64) { if let p = people.first { swipe(p, liked: false) } }
                        .accessibilityLabel("Skip")
                    roundButton("heart.fill", rose, size: 76) { if let p = people.first { swipe(p, liked: true) } }
                        .accessibilityLabel("Like")
                }.disabled(people.isEmpty).opacity(people.isEmpty ? 0.4 : 1).padding(.bottom, 10)
            }.padding(.horizontal, 14).padding(.top, 4)
                .background(Color(red: 0.985, green: 0.975, blue: 0.97).ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
        }
    }
    private func openAgents(_ p: DateProfile) {
        withAnimation { matchMoment = nil }
        tab = 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { chatMatch = p }
    }
    private func matchOverlay(_ p: DateProfile) -> some View {
        let first = p.name.components(separatedBy: " ").first ?? p.name
        return ZStack {
            LinearGradient(colors: [Color(red: 0.93, green: 0.36, blue: 0.47), rose, plum], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 26) {
                HStack { Spacer(); Button { withAnimation { matchMoment = nil } } label: { Image(systemName: "xmark").font(.title3.weight(.bold)).foregroundStyle(.white.opacity(0.8)).padding(12) }.accessibilityLabel("Close") }
                Spacer()
                Text("It's a match").font(.system(size: 50, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                HStack(spacing: -26) {
                    MyAvatar(size: 138).overlay(Circle().strokeBorder(.white, lineWidth: 4))
                    ProfilePortrait(person: p, size: 138).overlay(Circle().strokeBorder(.white, lineWidth: 4))
                }.shadow(color: .black.opacity(0.25), radius: 18, y: 8)
                Text("You and \(first) · \(chemistry(p))%").font(.system(.title3, design: .rounded).weight(.medium)).foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button { openAgents(p) } label: {
                    Label("Let your agents talk", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(rose)
                        .frame(maxWidth: .infinity, minHeight: 60).background(.white, in: Capsule())
                }.padding(.horizontal, 28).padding(.bottom, 30)
            }
        }.task {
            guard UserDefaults.standard.bool(forKey: "uiShotChat") else { return }
            try? await Task.sleep(for: .seconds(1)); openAgents(p)
        }
    }
    @AppStorage("openDate.selfNote") private var selfNote=""
    @AppStorage("openDate.selfReflection") private var selfReflection=""
    @AppStorage("openDate.encounterNote") private var encounterNote=""
    @AppStorage("openDate.encounterReflection") private var encounterReflection=""
    @State private var working=false
    @State private var learnedTick=0
    @State private var hardNos=SecondYouTraining.load().hardNos
    @State private var distance = 0.35
    @State private var liveProfile: DateProfile = {
        if let data = UserDefaults.standard.data(forKey:"openDate.profile"), let saved = try? JSONDecoder().decode(DateProfile.self,from:data) { return saved }
        return DateProfile(name:"Guest",interests:["Design","Music"],lookingFor:"Someone to explore with",symbol:"sun.max.fill")
    }()
    private var nearby: [Encounter] {
        guard open else { return [] }
        let floorPeople = building.people.enumerated().filter { !roomOnly || $0.offset == currentRoom }.map(\.element)
        let pool = demo ? floorPeople.map { Encounter(profile:$0,strength:-65) } : room.peers.filter {
            !floorCode.isEmpty && $0.profile.floorCode == normalizedFloorCode
        }
        return pool.filter { !dismissed.contains($0.id) }.sorted {
            let a = score($0.profile), b = score($1.profile)
            return a == b ? $0.profile.name < $1.profile.name : a > b
        }
    }
    private var recommendations: [Encounter] { nearby.filter { score($0.profile) >= 3 } }
    private var normalizedFloorCode: String { floorCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    private func startOnFloor() {
        var advertised = liveProfile
        advertised.floorCode = normalizedFloorCode
        room.start(advertised)
    }
    private func common(_ p:DateProfile) -> [String] { profile.interests.filter(p.interests.contains) }
    private func score(_ p:DateProfile) -> Int { common(p).count * 2 + (profile.lookingFor == p.lookingFor ? 1 : 0) }
    private var candidate: Encounter? { nearby.first { score($0.profile)>0 && $0.strength >= -72 && !alerted.contains($0.id) } }
    private func match() {
        guard instant, open, banner == nil, selected == nil, let encounter=candidate else {return}
        banner=encounter.profile; alerted.insert(encounter.id)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let note=UNMutableNotificationContent();note.title="Open Date · Suggested profile"
        note.body="Someone nearby shares your preferences. Open the room to see your signal."
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {return}
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:"open-date-nearby",content:note,trigger:nil))
        }
    }
    private func leave() { likes=[]; open=false; instant=false; banner=nil; selected=nil; dismissed=[]; alerted=[]; room.stop() }
    private func find(_ p:DateProfile) { banner=nil; distance=0.35; selected=p }
    private func skip(_ p:DateProfile) { dismissed.insert(p.id); banner=nil; selected=nil }
    private func remember(_ p:DateProfile) {
        guard !saved.contains(where:{$0.id==p.id}) else { return }
        if demo { demoSaved.append(p); return }
        liveSaved.append(p)
        UserDefaults.standard.set(try? JSONEncoder().encode(liveSaved),forKey:"openDate.matches")
    }
    private func like(_ p:DateProfile) {
        likes.insert(p.id)
        if demo { remember(p) }
        else { room.like(p.id); if room.incoming.contains(p.id) {remember(p)} }
        detail=nil
    }
    // MARK: Autopilot — the agent runs the whole date pipeline; the human only approves.
    @State private var autoStage = 0
    @State private var autoPick = 0
    @State private var autoRun = 0
    @State private var autoChat: DateProfile?
    @State private var autoPlan: DateProfile?
    @State private var autoDebrief: DateProfile?

    private var autoCandidates: [DateProfile] {
        var pool = saved
        if demo {
            let crowd = Array(DemoCrowd.people.prefix(12))
            let sharp = crowd.filter { PortraitStore.hasHD($0) }
            pool = sharp.count >= 3 ? sharp : crowd
        }
        var ranked = pool.sorted { (chemistry($0), $0.name) > (chemistry($1), $1.name) }
        // Demo story: Remy is the record-fair match, so lead with Remy.
        if demo, let i = ranked.firstIndex(where: { $0.id == DateProfile.examples[2].id }) { ranked.insert(ranked.remove(at: i), at: 0) }
        return Array(ranked.prefix(3))
    }
    private var autoPerson: DateProfile? {
        let c = autoCandidates
        return c.isEmpty ? nil : c[autoPick % c.count]
    }
    private func autoPlanKey(_ p: DateProfile) -> String { "openDate.datePlan." + p.id.uuidString }
    private func autoStoredPlan(_ p: DateProfile) -> (place: String, time: Date)? {
        guard let d = UserDefaults.standard.dictionary(forKey: autoPlanKey(p)),
              let time = d["time"] as? Date, let place = d["place"] as? String else { return nil }
        return (place, time)
    }
    private func autoPlanLabel(_ p: DateProfile) -> String {
        guard let plan = autoStoredPlan(p) else { return "Plan drafted" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = Calendar.current.component(.minute, from: plan.time) == 0 ? "EEE ha" : "EEE h:mma"
        let when = f.string(from: plan.time).replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
        return plan.place + " · " + when
    }
    private func autoDraftDemoPlan(_ p: DateProfile) {
        guard demo else { return }
        let places = ["Record fair", "Ruby Wine, Potrero Hill", "Sunset walk, Ocean Beach"]
        let saturday = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 14, weekday: 7), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(6 * 86400)
        UserDefaults.standard.set(["place": places[autoPick % places.count], "time": saturday, "confirmed": false], forKey: autoPlanKey(p))
    }
    private func autoAdvance() async {
        guard let p = autoPerson else { return }
        if autoStage < 3 { autoDraftDemoPlan(p) }
        while autoStage < 3 {
            do { try await Task.sleep(for: .seconds(autoStage == 0 ? 1.1 : 0.95)) } catch { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { autoStage += 1 }
            UIImpactFeedbackGenerator(style: autoStage == 3 ? .medium : .soft).impactOccurred()
        }
        // Screenshot/test hooks (launch arguments only).
        if UserDefaults.standard.bool(forKey: "uiShotAutoConfirm"), autoStage == 3 { autoConfirm(p) }
        switch UserDefaults.standard.string(forKey: "uiShotAutoSheet") {
        case "chat": autoChat = p
        case "plan": autoPlan = p
        case "debrief": autoDebrief = p
        default: break
        }
    }
    private func autoConfirm(_ p: DateProfile) {
        guard let plan = autoStoredPlan(p) else { autoPlan = p; return }
        UserDefaults.standard.set(["place": plan.place, "time": plan.time, "confirmed": true], forKey: autoPlanKey(p))
        remember(p)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { autoStage = 4 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard autoStage == 4 else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { autoStage = 5 }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
    private func autoRow(_ index: Int, icon: String, doing: String, done: String, action: (() -> Void)? = nil, @ViewBuilder trailing: () -> some View = { EmptyView() }) -> some View {
        let finished = autoStage > index
        return Button { action?() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(finished ? .white : rose)
                    .frame(width: 40, height: 40)
                    .background(finished ? rose : rose.opacity(0.12), in: Circle())
                Text(finished ? done : doing)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(finished ? plum : plum.opacity(0.55))
                    .lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                if finished {
                    trailing()
                    if action != nil { Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(plum.opacity(0.25)) }
                } else {
                    ProgressView().tint(rose)
                }
            }.padding(.vertical, 9).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!finished || action == nil)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    private var autopilot: some View {
        let person = autoPerson
        let candidates = autoCandidates
        return NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "heart.circle.fill").foregroundStyle(rose)
                            Text("open date").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(rose)
                            Spacer()
                            Button {
                                autoPick = 0
                                withAnimation(.spring(duration: 0.3)) { autoStage = 0 }
                                autoRun += 1
                            } label: {
                                Image(systemName: "arrow.counterclockwise").font(.body.weight(.semibold)).foregroundStyle(plum.opacity(0.45))
                            }.accessibilityLabel("Replay")
                        }.padding(.horizontal, 6)
                        Color(red: 0.96, green: 0.90, blue: 0.92).frame(height: 220)
                            .overlay {
                                if let person, let photo = PortraitStore.image(person) {
                                    Image(uiImage: photo).resizable().scaledToFill().id(person.id).transition(.opacity)
                                } else {
                                    Image(systemName: "sparkles").font(.system(size: 80)).foregroundStyle(rose.opacity(0.3))
                                }
                            }
                            .clipped()
                            .overlay(LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom))
                            .overlay(alignment: .bottomLeading) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Your agent is dating for you").font(.system(size: 24, weight: .heavy, design: .rounded))
                                    Text("You only approve.").font(.system(.subheadline, design: .rounded).weight(.medium)).opacity(0.9)
                                }.foregroundStyle(.white).padding(18)
                            }
                            .overlay(alignment: .topTrailing) {
                                if let person, autoStage >= 2 {
                                    Label("\(chemistry(person))% · " + (person.name.split(separator: " ").first.map(String.init) ?? person.name), systemImage: "sparkles")
                                        .font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(rose)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(.white, in: Capsule()).padding(14)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                        VStack(spacing: 0) {
                            autoRow(0, icon: "bubble.left.and.bubble.right.fill",
                                    doing: person == nil ? "Looking for people nearby…" : "Agents talking…",
                                    done: "Met \(demo ? 12 : max(nearby.count, candidates.count)) agents",
                                    action: { autoChat = person })
                            if autoStage >= 1 {
                                autoRow(1, icon: "checkmark.shield.fill", doing: "Vetting…",
                                        done: "\(candidates.count) strong match" + (candidates.count == 1 ? "" : "es"),
                                        action: { autoChat = person }) {
                                    HStack(spacing: -10) {
                                        ForEach(candidates) { c in
                                            ProfilePortrait(person: c, size: 30).opacity(c.id == person?.id ? 1 : 0.55)
                                        }
                                    }
                                }
                            }
                            if autoStage >= 2, let person {
                                autoRow(2, icon: "calendar", doing: "Agreeing on a plan…", done: autoPlanLabel(person),
                                        action: { autoPlan = person })
                            }
                            if autoStage == 3, let person {
                                VStack(spacing: 10) {
                                    HStack(spacing: 14) {
                                        ProfilePortrait(person: person, size: 40)
                                        Text("Waiting for you").font(.system(.headline, design: .rounded)).foregroundStyle(plum)
                                        Spacer()
                                    }
                                    Button { autoConfirm(person) } label: {
                                        Text("Confirm date").font(.system(.title3, design: .rounded).weight(.bold))
                                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                                            .background(rose, in: Capsule()).foregroundStyle(.white)
                                    }
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        autoPick += 1
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { autoStage = 1 }
                                        autoRun += 1
                                    } label: {
                                        Text("Not this one").font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(plum.opacity(0.55)).padding(.vertical, 4)
                                    }
                                }.buttonStyle(.plain).padding(.vertical, 9)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            if autoStage >= 4, let person {
                                autoRow(3, icon: "hand.thumbsup.fill", doing: "", done: "Plan confirmed", action: { autoPlan = person }) {
                                    Text("Planned").font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(rose)
                                        .padding(.horizontal, 9).padding(.vertical, 4).background(rose.opacity(0.12), in: Capsule())
                                }
                            }
                            if autoStage >= 5, let person {
                                autoRow(4, icon: "mic.fill", doing: "", done: "After the date: tap to debrief", action: { autoDebrief = person })
                            }
                            Color.clear.frame(height: 1).id("autoEnd")
                        }.padding(.horizontal, 16).padding(.vertical, 8)
                            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                    }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
                }.background(Color(red: 0.985, green: 0.965, blue: 0.97))
                    .onChange(of: autoStage) { withAnimation(.spring(duration: 0.4)) { reader.scrollTo("autoEnd", anchor: .bottom) } }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: autoRun) { await autoAdvance() }
            .sheet(item: $autoChat) { p in
                NavigationStack { agentConversation(p).toolbar { Button("Done") { autoChat = nil } } }
            }
            .sheet(item: $autoPlan) { p in MatchDatePlanner(person: p, demo: demo) }
            .sheet(item: $autoDebrief) { p in
                NavigationStack {
                    let plan = autoStoredPlan(p)
                    DateDebrief(date: ReviewDate(id: autoPlanKey(p), person: p, time: plan?.time ?? Date(), place: plan?.place ?? "Date"), demo: demo)
                        .toolbar { Button("Done") { autoDebrief = nil } }
                }
            }
        }
    }
    var body: some View {
        TabView(selection:$tab) {
            autopilot.tabItem{Image(systemName:"sparkles").accessibilityLabel("Autopilot")}.tag(3)
            deck.tabItem{Image(systemName:"rectangle.stack.fill").accessibilityLabel("Browse")}.tag(0)
            matches.tabItem{Image(systemName:"heart.fill").accessibilityLabel("Matches")}.tag(2)
            secondYou.tabItem{Image(systemName:"person.fill").accessibilityLabel("You")}.tag(1)
        }.tint(rose).preferredColorScheme(.light)
        .overlay { if let p = matchMoment { matchOverlay(p).transition(.opacity.combined(with: .scale(scale: 1.08))) } }
        .task(id: saved.map(\.id)) { await prepareExchanges() }
        .onChange(of:room.incoming){ ids in
            for p in nearby.map(\.profile) where ids.contains(p.id) && likes.contains(p.id) {
                let fresh = !saved.contains { $0.id == p.id }
                remember(p)
                if fresh { withAnimation(.spring(duration: 0.4)) { matchMoment = p } }
            }
        }
        .sheet(item: $directory, onDismiss: {
            if let person = directorySelection { detail = person; directorySelection = nil }
        }) { group in
            NavigationStack {
                List(group.people) { person in
                    Button {
                        directorySelection = person
                        directory = nil
                    } label: {
                        HStack {
                            ProfilePortrait(person: person, size: 42)
                            VStack(alignment: .leading) {
                                Text(person.name).font(.headline)
                                Text(person.interests.joined(separator: " · ")).font(.caption)
                            }
                        }
                    }.buttonStyle(.plain)
                }.navigationTitle(group.title)
                    .toolbar { Button("Done") { directory = nil } }
            }
        }
        .sheet(isPresented:$editing){editor}
        .sheet(item:$selected){p in signal(p)}
        .sheet(item:$detail){p in
            if score(p) >= 3 {
                chemistryDetail(p)
            } else {
            VStack(alignment:.leading,spacing:20){
                ProfilePortrait(person: p, size: 68)
                Text(p.name).font(.system(size:38,design:.serif))
                Text(p.lookingFor).font(.title3)
                profileFacts(p)
                Text(p.interests.joined(separator:"  ·  "));if let personality=p.personality,!personality.isEmpty{Text(personality)}
                if demo {Text("Fictional demo profile · likes you back").font(.caption).foregroundStyle(.secondary)}
                if saved.contains(where:{$0.id==p.id}) {Button("View match"){detail=nil;tab=2}}
                else {Button(likes.contains(p.id) ? "Send interest again" : "Like "+p.name){like(p)}.buttonStyle(.borderedProminent)}
                Button("Pass"){skip(p);detail=nil}
            }.padding(28).frame(maxWidth:.infinity,alignment:.leading).presentationDetents([.medium,.large]).tint(rose)
            }
        }
    }
    private func chemistryDetail(_ p: DateProfile) -> some View {
        let shared = common(p)
        let sameGoal = profile.lookingFor == p.lookingFor
        let total = max(1, max(profile.interests.count, p.interests.count))
        let interestRatio = Double(shared.count) / Double(total)
        // Preview index for recommended profiles, derived only from declared preferences.
        let measured = demo ? nil : exchanges[p.id]
        let chemistry = measured?.score.map { Int(($0 * 100).rounded()) } ?? Int((52 + 30 * interestRatio + (sameGoal ? 18 : 0)).rounded())
        let alreadyMatched = saved.contains { $0.id == p.id }
        let pink = Color(red: 1, green: 0.58, blue: 0.81)
        let surface = Color(red: 0.19, green: 0.14, blue: 0.23)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Second You found someone").font(.subheadline)
                    Spacer()
                    Button { detail = nil } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
                        .accessibilityLabel("Close profile")
                }
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(chemistry)% chemistry").font(.system(size: 38, weight: .semibold, design: .serif))
                    if let m = measured, let lo = m.low, let hi = m.high {
                        Text("From your agents' chat on this phone: likely \(Int(lo * 100))% to \(Int(hi * 100))%").font(.caption).foregroundStyle(pink)
                    }
                    HStack(spacing: 14) {
                        MyAvatar().scaleEffect(1.9).frame(width: 78, height: 78)
                            .overlay(Circle().strokeBorder(pink, lineWidth: 2))
                        ProfilePortrait(person: p, size: 78)
                            .overlay(Circle().strokeBorder(pink, lineWidth: 2))
                    }.frame(maxWidth: .infinity)
                    Text(p.name).font(.title2.bold())
                    profileFacts(p)
                    Text(p.interests.joined(separator: " · ")).font(.subheadline)
                    Button {
                        if alreadyMatched { detail = nil; tab = 2 } else { like(p); if demo { tab = 2 } }
                    } label: {
                        Text(alreadyMatched ? "View match" : "Say hi").fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    }.background(pink, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black)
                }.padding(20).background(surface, in: RoundedRectangle(cornerRadius: 22))
                VStack(alignment: .leading, spacing: 12) {
                    Text("Why you are matched").font(.headline)
                    Divider().overlay(.white.opacity(0.2))
                    Text("Shared interests").font(.subheadline.bold())
                    Text(shared.joined(separator: " · "))
                    Divider().overlay(.white.opacity(0.2))
                    Text("Dating preferences").font(.subheadline.bold())
                    Text(sameGoal ? "You’re both looking for: " + p.lookingFor : p.name + " is looking for: " + p.lookingFor)
                    Text("Chemistry is a preview score based on your listed interests and dating preferences.").font(.footnote).foregroundStyle(.white.opacity(0.7))
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(surface, in: RoundedRectangle(cornerRadius: 22))
            }.padding(20)
        }.background(Color(red: 0.095, green: 0.065, blue: 0.12)).foregroundStyle(.white)
            .presentationDetents([.large]).presentationDragIndicator(.visible)
    }
    @State private var exchanges: [UUID: AgentExchange] = [:]
    @State private var partial: [UUID: [String]] = [:]

    private func prepareExchanges() async {
        for person in saved {
            guard !Task.isCancelled else { return }
            guard !demo, exchanges[person.id] == nil else { continue }
            let key = "openDate.agentExchange." + person.id.uuidString
            if !demo, let data = UserDefaults.standard.data(forKey: key),
               let cached = try? JSONDecoder().decode(AgentExchange.self, from: data) {
                exchanges[person.id] = cached
                continue
            }
            let transcript = await AgentExchange.generate(profile, person) { lines in partial[person.id] = lines }
            guard !Task.isCancelled else { return }
            exchanges[person.id] = transcript
            partial[person.id] = nil
            if !demo { UserDefaults.standard.set(try? JSONEncoder().encode(transcript), forKey: key) }
        }
    }

    @State private var chatMatch: DateProfile?
    @State private var planningMatch: DateProfile?

    private var settings: some View {
        NavigationStack {
            List {
                Button("Edit profile") { editing = true }
                Button("Location and notification permissions") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }.navigationTitle("Settings")
        }
    }
    @State private var reviewingMatch: DateProfile?
    @State private var pastDates: [ReviewDate] = []
    private func refreshDates() { pastDates = DateHistory.load(people: saved, demo: demo) }

    private var matches: some View {
        NavigationStack {
            List {
                if saved.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "heart.circle.fill").font(.system(size: 56)).foregroundStyle(rose.opacity(0.3))
                        Text("No matches yet").font(.system(.headline, design: .rounded)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 60).listRowSeparator(.hidden)
                }
                ForEach(saved) { person in
                    let hasHistory = pastDates.contains { $0.person.id == person.id }
                    HStack(spacing: 14) {
                        ProfilePortrait(person: person, size: 68)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.name).font(.system(.title3, design: .rounded).weight(.semibold))
                            Text(person.interests.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button { find(person) } label: {
                            Image(systemName: "location.fill").frame(width: 42, height: 42).background(rose.opacity(0.1), in: Circle())
                        }.accessibilityLabel("Find " + person.name)
                        Button { if hasHistory { reviewingMatch = person } else { planningMatch = person } } label: {
                            Image(systemName: hasHistory ? "sparkles" : "calendar").foregroundStyle(.white)
                                .frame(width: 42, height: 42).background(rose, in: Circle())
                        }.accessibilityLabel(hasHistory ? "Analyze date" : "Arrange date")
                    }.buttonStyle(.borderless).padding(.vertical, 8)
                        .contentShape(Rectangle()).onTapGesture { chatMatch = person }
                        .listRowSeparator(.hidden)
                }.onDelete { offsets in
                    for index in offsets {
                        let id = saved[index].id
                        exchanges[id] = nil
                        partial[id] = nil
                        if !demo { UserDefaults.standard.removeObject(forKey: "openDate.agentExchange." + id.uuidString) }
                    }
                    if demo { demoSaved.remove(atOffsets: offsets) }
                    else {
                        liveSaved.remove(atOffsets: offsets)
                        UserDefaults.standard.set(try? JSONEncoder().encode(liveSaved), forKey: "openDate.matches")
                    }
                }
            }.listStyle(.plain).navigationTitle("Matches")
                .onAppear(perform: refreshDates)
                .onChange(of: saved) { refreshDates() }
                .sheet(item: $reviewingMatch) { person in
                    NavigationStack {
                        let dates = pastDates.filter { $0.person.id == person.id }
                        Group {
                            if dates.count == 1, let date = dates.first { DateDebrief(date: date, demo: demo) }
                            else { DateHistory(dates: dates, demo: demo) }
                        }.toolbar { Button("Done") { reviewingMatch = nil } }
                    }
                }
                .sheet(item: $chatMatch) { person in
                    NavigationStack {
                        agentConversation(person)
                            .toolbar { Button("Done") { chatMatch = nil } }
                    }
                }
                .sheet(item: $planningMatch, onDismiss: refreshDates) { person in MatchDatePlanner(person: person, demo: demo) }
        }
    }

    private func agentConversation(_ person: DateProfile) -> some View {
        let exchange = demo ? AgentExchange.suggested(profile, person) : exchanges[person.id]
        let lines = exchange?.lines ?? partial[person.id] ?? []
        let pink = rose
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ProfilePortrait(person: person, size: 48)
                    VStack(alignment: .leading) {
                        Text(person.name).font(.system(.title2, design: .rounded).bold())
                        Text(exchange == nil ? "Agents talking…" : exchange?.onDevice == true ? "On-device agents" : "Demo agents").font(.caption).foregroundStyle(.secondary)
                        if let e = exchange, let score = e.score {
                            Text("Chemistry \(Int((score * 100).rounded()))%" + (e.low.map { " · likely \(Int($0 * 100))% to \(Int((e.high ?? $0) * 100))%" } ?? "")).font(.caption.bold()).foregroundStyle(pink)
                            if e.clash == true { Text("A hard no came up, so Second You held back").font(.caption) }
                            if !(e.invented ?? []).isEmpty { Text("Your agent said something your profile doesn't back up. Worth a look.").font(.caption) }
                        }
                    }
                }
                ForEach(AgentExchange.topics.indices, id: \.self) { topic in
                    if lines.count > topic * 2 {
                        Text(AgentExchange.topics[topic]).font(.caption.bold()).foregroundStyle(pink).padding(.top, 6)
                        ForEach(topic * 2..<min(lines.count, topic * 2 + 2), id: \.self) { i in
                            let mine = i.isMultiple(of: 2)
                            HStack {
                                if mine { Spacer(minLength: 28) }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text((mine ? profile.name : person.name) + "’s agent").font(.caption.bold()).foregroundStyle(pink)
                                    Text(lines[i]).font(.subheadline)
                                }.padding(12).background(mine ? rose.opacity(0.12) : Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                if !mine { Spacer(minLength: 28) }
                            }
                        }
                    }
                }
                if exchange == nil { ProgressView().tint(pink) }

            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Color.white).foregroundStyle(plum)
            .navigationBarTitleDisplayMode(.inline)
    }
    private var secondYou: some View {
        let input = demo ? $demoSelfNote : $selfNote
        let portrait = demo ? $demoPortrait : $selfReflection
        let partner = demo ? $demoIdealPartner : $idealPartner
        let ideal = demo ? $demoIdealDate : $idealDate
        return NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Button { editing = true } label: { MyAvatar(size: 104) }.buttonStyle(.plain)
                        Text(profile.name).font(.system(.title, design: .rounded).bold()).foregroundStyle(plum)
                        Text(profile.interests.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).listRowBackground(Color.clear)
                }
                Section {
                    if let job = profile.occupation, !job.isEmpty { LabeledContent("Work", value: job) }
                    if let school = profile.education, !school.isEmpty { LabeledContent("Education", value: school) }
                    DisclosureGroup("In my own words") {
                        TextField("What do you enjoy or value?", text: input, axis: .vertical)
                        Button(working ? "Building portrait…" : "Build my portrait") {
                            working = true
                            Task {
                                if !demo { SecondYouTraining.learn(input.wrappedValue); learnedTick += 1 }
                                portrait.wrappedValue = await PersonalInsights.reflect(text: input.wrappedValue, profile: profile, afterMeeting: false)
                                working = false
                            }
                        }.disabled(working || input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if !portrait.wrappedValue.isEmpty { Text(portrait.wrappedValue).font(.subheadline) }
                    }
                } header: { Label("About", systemImage: "person.fill") }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Who I’d like to meet").font(.subheadline.bold())
                        TextField("Qualities that matter", text: partner, axis: .vertical)
                    }.padding(.vertical, 4)
                    LabeledContent("Looking for", value: profile.lookingFor)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My kind of first date").font(.subheadline.bold())
                        TextField("Where, and doing what?", text: ideal, axis: .vertical)
                            .font(.body)
                    }.padding(.vertical, 4)
                } header: { Label("Ideal date", systemImage: "heart.fill") }
                Section {
                    let t = learnedTick >= 0 ? SecondYouTraining.traits() : SecondYouTraining.Traits()
                    if t.lines == 0 {
                        Text("Add a note above to train Second You.").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        LabeledContent("Learned from", value: "\(t.lines) things you said")
                        LabeledContent("Your style", value: "about \(t.avgWords) words, questions \(t.asksQuestions)% of the time")
                        if !t.phrases.isEmpty { LabeledContent("You often say", value: t.phrases.joined(separator: " · ")) }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My hard nos").font(.subheadline.bold())
                        TextField("Never compromise on…", text: $hardNos, axis: .vertical)
                            .onChange(of: hardNos) { _, v in SecondYouTraining.setHardNos(v) }
                    }.padding(.vertical, 4)
                    Label("Stays on this iPhone", systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary)
                    Button("Forget what it learned", role: .destructive) { SecondYouTraining.wipe(); hardNos = ""; learnedTick += 1 }
                } header: { Label("Second You", systemImage: "sparkles") }
                Section {
                    Button { editing = true } label: { Label("Edit profile", systemImage: "pencil") }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: { Label("Permissions", systemImage: "gearshape") }
                } header: { Label("Settings", systemImage: "gearshape.fill") }
            }.navigationTitle("You")
        }
    }
    private var discovery: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                HStack {
                    Image(systemName:"circle.hexagongrid.fill").foregroundStyle(rose)
                    Text("OPEN DATE").font(.system(.subheadline,design:.rounded).weight(.bold)).tracking(2)
                    Spacer()
                    Button { editing=true } label:{ MyAvatar() }.accessibilityLabel("Edit my profile")
                }
                if demo {
                        HStack {
                            Text("Around you").font(.system(.title, design: .serif))
                            Spacer()
                            Button(open ? "Leave" : "Enter") { if open { leave() } else { open = true } }
                        }
                        if open {
                            DeviceMap(people: nearby.map(\.profile), compatible: Set(recommendations.map(\.id))) { members in
                                directory = PeopleDirectory(title: "Here on the map", people: members)
                            }
                        }
                } else {
                VStack(alignment:.leading,spacing:16){
                    HStack { Image(systemName:"dot.radiowaves.left.and.right"); Text(demo ? "SIMULATED ROOM":"BLUETOOTH ROOM").font(.caption.bold()).tracking(1.6);Spacer() }
                    Text(open ? "Open to meet." : "Open to date?").font(.system(size:41,weight:.medium,design:.serif))
                    Text(open ? (demo ? "You’re here as \(profile.name). Tap a profile to see what you have in common, or find Remy in Matches." : room.status) : (demo ? "Try the experience with three fictional people." : "Share your chosen name, interests and dating preferences with other opted-in phones nearby.")).font(.subheadline)
                    if !open {
                        TextField("Building + floor code", text: $floorCode)
                            .textFieldStyle(.roundedBorder).foregroundStyle(plum)
                        Text("Enter the same building and floor code as others on your floor.").font(.footnote)
                    } else {
                        Text("Checked in · " + normalizedFloorCode)
                        Text("\(nearby.count) others on this floor").font(.headline)
                    }
                    Button(open ? "Leave room" : "Enter room"){if open {leave()} else {open=true;if !demo {startOnFloor()}}}
                        .disabled(!open && normalizedFloorCode.isEmpty).buttonStyle(.borderedProminent).tint(.white).foregroundStyle(plum)
                }.foregroundStyle(.white).padding(24).frame(maxWidth:.infinity,alignment:.leading).background(plum,in:RoundedRectangle(cornerRadius:26))
                }
                if open {
                    Toggle("Instant matching", isOn: $instant)
                        .font(.headline).tint(rose)
                        .onChange(of: instant) { _, enabled in
                            banner = nil
                            analyzing = false
                            finishedScan = false
                            if enabled { alerted.removeAll() }
                        }
                    if instant {
                        if let person = banner {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested for you").font(.caption.bold()).foregroundStyle(rose)
                                HStack {
                                    ProfilePortrait(person: person, size: 58)
                                    Text(person.name).font(.title2.bold())
                                }
                                profileFacts(person)
                                Text(person.interests.joined(separator: " · ")).font(.subheadline)
                                HStack {
                                    Button("View profile") { detail = person }.buttonStyle(.borderedProminent)
                                    Button("Pass") { finishedScan = false; analyzing = false; skip(person) }
                                }
                            }.padding().frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        } else {
                            Group {
                                if finishedScan {
                                    Text("No suggested profiles nearby yet.")
                                } else {
                                    MatchActivity(analyzing: analyzing)
                                }
                            }
                                .task(id: candidate?.id) {
                                    analyzing = false
                                    finishedScan = false
                                    do {
                                        try await Task.sleep(for: .seconds(2))
                                        analyzing = true
                                        try await Task.sleep(for: .seconds(2))
                                        match()
                                        finishedScan = true
                                    } catch { return }
                                }
                        }
                    }
                    directoryButton("Open to date", people: nearby.map(\.profile))
                    if nearby.isEmpty {
                        Text("No one else is open to date here yet.").foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 16) {
                                ForEach(nearby) { encounter in
                                    Button { detail = encounter.profile } label: {
                                        VStack {
                                            ProfilePortrait(person: encounter.profile, size: 52)
                                            Text(encounter.profile.name).font(.subheadline)
                                        }
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.vertical, 2)
                        }.scrollIndicators(.hidden)
                    }
                    directoryButton("High compatibility", people: recommendations.map(\.profile))
                    if recommendations.isEmpty {
                        Text("No close preference matches here yet.").foregroundStyle(.secondary)
                    }
                    ForEach(recommendations.prefix(12)) { encounter in
                        let person = encounter.profile
                        Button { detail = person } label: {
                            HStack(spacing: 12) {
                                ProfilePortrait(person: person, size: 44)
                                VStack(alignment: .leading) {
                                    Text(person.name).font(.headline)
                                    Text("Both into " + common(person).joined(separator: " & ")).font(.subheadline)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }.padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20)
        }.background(Color(red:0.98,green:0.96,blue:0.94)).foregroundStyle(plum).tint(rose)
        .onChange(of: nearby.map(\.id)) { _, ids in
            if let current = banner, !ids.contains(current.id) { banner = nil }
        }



    }
    @State private var photoItem: PhotosPickerItem?
    @AppStorage("openDate.avatarBytes") private var avatarBytes = Data()
    @State private var directory: PeopleDirectory?
    @State private var directorySelection: DateProfile?
    private func directoryButton(_ title: String, people: [DateProfile]) -> some View {
        Button {
            directory = PeopleDirectory(title: title, people: people)
        } label: {
            HStack {
                Text(title).font(.system(.title, design: .serif))
                Spacer()
                Text("\(people.count)").monospacedDigit()
                Image(systemName: "chevron.right").font(.caption)
            }
        }.buttonStyle(.plain)
    }
    @ViewBuilder private func profileFacts(_ person: DateProfile) -> some View {
        if let work = person.occupation, !work.isEmpty { Label(work, systemImage: "briefcase") }
        if let school = person.education, !school.isEmpty { Label(school, systemImage: "graduationcap") }
    }
    private var editor: some View {
        NavigationStack {Form {
            Section {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack { MyAvatar(); Text("Choose profile photo") }
                }.task(id: photoItem) {
                    guard let data = try? await photoItem?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let thumb = await image.byPreparingThumbnail(ofSize: CGSize(width: 240, height: 240)),
                          !Task.isCancelled, let jpg = thumb.jpegData(compressionQuality: 0.85) else { return }
                    avatarBytes = jpg
                }
            }
            Section("Your room profile"){ TextField("First name",text:profileBinding.name)
                TextField("Work", text: Binding(get: { profile.occupation ?? "" }, set: { profileBinding.wrappedValue.occupation = String($0.prefix(80)) }))
                TextField("Education", text: Binding(get: { profile.education ?? "" }, set: { profileBinding.wrappedValue.education = String($0.prefix(80)) }))
                TextField("How you describe yourself", text: Binding(get:{profile.personality ?? ""},set:{profileBinding.wrappedValue.personality=String($0.prefix(160))}))
                Picker("Looking for",selection:profileBinding.lookingFor){ForEach(["Someone to explore with","An adventure buddy","A creative collaborator"],id:\.self){Text($0)}}
            }
            Section("Your interests"){ForEach(DateProfile.choices,id:\.self){interest in
                Button{if profile.interests.contains(interest){profileBinding.wrappedValue.interests.removeAll{$0==interest}} else {profileBinding.wrappedValue.interests.append(interest)}}label:{HStack{Text(interest);Spacer();if profile.interests.contains(interest){Image(systemName:"checkmark")}}}
            }}
        }.navigationTitle("Your profile").toolbar {Button("Done"){editing=false}.disabled(profile.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}
        }.onDisappear {
            profileBinding.wrappedValue.name=String(profile.name.trimmingCharacters(in:.whitespacesAndNewlines).prefix(40));if profile.name.isEmpty {profileBinding.wrappedValue.name="Guest"}
            guard !demo else {return}
            UserDefaults.standard.set(try? JSONEncoder().encode(profile),forKey:"openDate.profile")
            if open && !demo {startOnFloor()}
        }
    }
    private func signal(_ p:DateProfile)->some View {
        let live=nearby.first{$0.id==p.id}
        let level=demo ? distance : min(1,max(0,Double((live?.strength ?? -95)+95)/55))
        let pair=[p.id.uuidString,profile.id.uuidString].sorted().joined().utf8.reduce(0){($0+Int($1))%360}
        let shape=DateProfile.cues[pair % DateProfile.cues.count]
        let glow=Color(hue:Double(pair)/360,saturation:0.72,brightness:1)
        return VStack(spacing:20){
            HStack{Text(demo ? "DEMO SIGNAL":"SHARED SIGNAL").font(.caption.bold()).tracking(2);Spacer();Button("Close"){selected=nil}};Spacer()
            ZStack {Circle().fill(glow.opacity(0.12+level*0.25)).frame(width:160+60*level,height:160+60*level);Image(systemName:shape).font(.system(size:62)).foregroundStyle(glow.opacity(0.4+level*0.6)).shadow(color:glow,radius:level*18)}
            Text("Find "+p.name).font(.system(size:36,design:.serif));Text(demo ? "Move closer to brighten your shared signal." : live == nil ? "Signal lost. Return to the room to find someone nearby." : "Choose each other on both phones to see the same symbol and color. A stronger Bluetooth signal brightens it.").multilineTextAlignment(.center)
            if demo {Slider(value:$distance,in:0...1).accessibilityLabel("Simulated proximity");HStack{Text("Farther");Spacer();Text("Closer")}.font(.caption)}
            Spacer();Button("Pass on this connection"){skip(p)}.buttonStyle(.bordered)
        }.padding(30).frame(maxWidth:.infinity,maxHeight:.infinity).background(plum).foregroundStyle(.white).tint(glow)
    }
}

private enum DemoBuilding: String, CaseIterable {
    case exchange = "The Exchange"
    case pavilion = "Garden Pavilion"

    var rooms: [String] {
        self == .exchange ? ["Atrium", "Studio", "Café"] : ["Gallery", "Workshop", "Lounge"]
    }

    var people: [DateProfile] {
        if self == .exchange { return DemoCrowd.people }
        return [Self.noor]
    }

    static let noor = DateProfile(id: UUID(uuidString: "00000000-0000-4000-A000-000000000004")!, name: "Noor", interests: ["Design", "Film"], lookingFor: "A creative collaborator", personality: "I spend Saturdays sketching at galleries.", symbol: "sparkles")

    // Relative floor coordinates, with a continuous corridor between the rooms.
    func bounds(for index: Int) -> CGRect {
        let split: CGFloat = self == .exchange ? 0.53 : 0.40
        let above: CGFloat = self == .exchange ? 0.48 : 0.61
        if index == 0 { return CGRect(x: 0.05, y: 0.08, width: split - 0.09, height: 0.84) }
        return CGRect(x: split + 0.05, y: index == 1 ? 0.08 : above + 0.06,
                      width: 0.90 - split, height: index == 1 ? above - 0.10 : 0.86 - above)
    }
}

private struct IndoorPlan: View {
    let building: DemoBuilding
    @Binding var currentRoom: Int
    let people: [DateProfile]
    let select: (DateProfile) -> Void
    private let ink = Color(red: 0.20, green: 0.29, blue: 0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(building.rooms[currentRoom], systemImage: "location.fill").font(.headline)
                Spacer()
                Text("Floor 1").font(.caption)
            }.padding(14)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Color(red: 0.92, green: 0.93, blue: 0.89)
                    ForEach(building.rooms.indices, id: \.self) { i in
                        let r = building.bounds(for: i).applying(CGAffineTransform(scaleX: geo.size.width, y: geo.size.height))
                        let active = currentRoom == i
                        ZStack(alignment: .topLeading) {
                            Rectangle().fill(active ? Color(red: 0.83, green: 0.89, blue: 0.81) : Color(red: 0.97, green: 0.95, blue: 0.89))
                            Rectangle().strokeBorder(ink.opacity(0.56), lineWidth: 2)
                            // Leave an opening in the corridor-facing wall.
                            Rectangle().fill(Color(red: 0.92, green: 0.93, blue: 0.89)).frame(width: 3, height: 18)
                                .position(x: i == 0 ? r.width - 1 : 1, y: r.height * 0.65)
                            Text(building.rooms[i].uppercased()).font(.caption2.bold()).tracking(1).padding(9)
                        }.frame(width: r.width, height: r.height).contentShape(Rectangle())
                            .onTapGesture { withAnimation { currentRoom = i } }
                            .accessibilityElement(children: .ignore).accessibilityLabel("Move to " + building.rooms[i])
                            .accessibilityAddTraits(.isButton)
                            .position(x: r.midX, y: r.midY)
                        if active {
                            MyAvatar().position(x: r.midX, y: r.maxY - 22).allowsHitTesting(false)
                        }
                        if let person = building.people.dropFirst(i).first, people.contains(where: { $0.id == person.id }) {
                            Button { select(person) } label: {
                                VStack(spacing: 1) {
                                    ProfilePortrait(person: person, size: 35)
                                    Text(person.name).font(.caption2.bold())
                                }
                            }.buttonStyle(.plain).accessibilityLabel("View " + person.name)
                                .position(x: r.midX, y: r.midY)
                        }
                    }
                }
            }.frame(height: 340)
        }.foregroundStyle(ink).background(.white, in: RoundedRectangle(cornerRadius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct MatchActivity: View {
    let analyzing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    private let accent = Color(red: 0.61, green: 0.16, blue: 0.31)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { frame in
            let elapsed = max(0, frame.date.timeIntervalSince(started))
            let secondSignal = reduceMotion || elapsed > 0.8
            HStack(spacing: 14) {
                if analyzing {
                    VStack(spacing: 8) {
                        signal("sparkles", active: true)
                        signal("heart.fill", active: secondSignal)
                    }.frame(width: 68)
                } else {
                    ZStack {
                        ForEach(0..<2) { ring in
                            let phase = reduceMotion ? Double(ring + 1) / 2 : (elapsed / 1.5 + Double(ring) / 2).truncatingRemainder(dividingBy: 1)
                            Circle().stroke(accent.opacity(0.65 - phase * 0.45), lineWidth: 1.5)
                                .frame(width: 29 + phase * 39, height: 29 + phase * 39)
                        }
                        MyAvatar().scaleEffect(0.68)
                        ForEach(0..<3) { index in
                            Circle().fill(accent).frame(width: 5, height: 5)
                                .offset(x: [-22, 19, 16][index], y: [-10, -17, 21][index])
                                .opacity(reduceMotion || elapsed > Double(index) * 0.38 ? 1 : 0)
                        }
                    }.frame(width: 68, height: 68)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(analyzing ? "Comparing profiles" : "Detecting nearby")
                        .font(.headline)
                    if analyzing {
                        Text("Shared interests").foregroundStyle(accent)
                        Text("Dating preferences").foregroundStyle(secondSignal ? accent : .secondary)
                    } else {
                        Text("Finding people open to date…").foregroundStyle(.secondary)
                    }
                }.font(.subheadline)
                Spacer(minLength: 0)
            }
        }
        .onChange(of: analyzing) { _, _ in started = Date() }
        .padding(14).frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .background(Color(red: 1, green: 0.96, blue: 0.96), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(analyzing ? "Comparing shared interests and dating preferences" : "Detecting people nearby")
    }

    private func signal(_ icon: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).frame(width: 18)
            Capsule().frame(width: 22, height: 2)
            Circle().frame(width: 7, height: 7)
        }.font(.caption).foregroundStyle(active ? accent : Color.gray.opacity(0.35))
    }
}

private struct ProfilePortrait: View {
    let person: DateProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let photo = PortraitStore.image(person) {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.teal, .white)
            }
        }.frame(width: size, height: size).clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
            .accessibilityLabel(person.name)
    }
}

private enum PortraitStore {
    static func resource(_ person: DateProfile) -> String {
        DemoCrowd.indices[person.id].map { $0 < 3 ? DateProfile.examples[$0].name.lowercased() : "guest" + String($0 - 3) } ?? (person.id == DemoBuilding.noor.id ? "noor" : "")
    }
    private static var hd: [String: Bool] = [:]
    static func hasHD(_ person: DateProfile) -> Bool {
        let r = resource(person)
        if r.isEmpty { return false }
        if let known = hd[r] { return known }
        let found = Bundle.main.path(forResource: "hd_" + r, ofType: "jpg", inDirectory: "Portraits") != nil
        hd[r] = found
        return found
    }
    static func image(_ person: DateProfile) -> UIImage? {
        let r = resource(person)
        if r.isEmpty { return nil }
        return (hasHD(person) ? UIImage(named: "Portraits/hd_" + r + ".jpg") : nil) ?? UIImage(named: "Portraits/" + r + ".jpg")
    }
}

private struct DeckCard: View {
    let person: DateProfile
    let chemistry: Int
    let showAge: Bool
    var body: some View {
        let first = person.name.components(separatedBy: " ").first ?? person.name
        let age = 24 + (DemoCrowd.indices[person.id] ?? 0) * 5 % 9
        return GeometryReader { g in
            ZStack(alignment: .bottomLeading) {
                if let photo = PortraitStore.image(person) {
                    Image(uiImage: photo).resizable().interpolation(.high).scaledToFill()
                        .frame(width: g.size.width, height: g.size.height).clipped()
                } else {
                    LinearGradient(colors: [Color(red: 0.93, green: 0.55, blue: 0.62), Color(red: 0.64, green: 0.18, blue: 0.31)], startPoint: .top, endPoint: .bottom)
                    Text(String(first.prefix(1))).font(.system(size: 140, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.35))
                        .frame(width: g.size.width, height: g.size.height)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(first).font(.system(size: 36, weight: .bold, design: .rounded))
                        if showAge { Text(String(age)).font(.system(size: 28, weight: .regular, design: .rounded)) }
                    }
                    Text(person.interests.joined(separator: " · ")).font(.system(.headline, design: .rounded)).opacity(0.92)
                }.foregroundStyle(.white).padding(22)
            }
            .overlay(alignment: .top) {
                Label("\(chemistry)% match", systemImage: "sparkles").font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.ultraThinMaterial.opacity(0.9), in: Capsule()).environment(\.colorScheme, .dark).padding(14)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
            .accessibilityElement(children: .combine)
    }
}

private struct MyAvatar: View {
    var size: CGFloat = 40
    @AppStorage("openDate.avatarBytes") private var bytes = Data()
    var body: some View {
        Group {
            if let photo = UIImage(data: bytes) {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.teal, .white)
            }
        }.frame(width: size, height: size).clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2)).shadow(radius: 2).accessibilityLabel("You")
    }
}

private final class DevicePosition: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var fix: CLLocation?
    @Published var message = "Finding your location…"
    private let manager = CLLocationManager()
    private var running = false
    private var timer: Timer?
    func start() {
        running = true
        #if targetEnvironment(simulator)
        readMac()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.readMac() }
        #else
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else { locationManagerDidChangeAuthorization(manager) }
        #endif
    }
    func stop() {
        running = false
        manager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        fix = nil
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard running else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
        case .denied, .restricted: fix = nil; message = "Allow location for Open Date in Settings."
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard running, let last = locations.last, last.horizontalAccuracy >= 0, abs(last.timestamp.timeIntervalSinceNow) < 60 else { return }
        fix = last
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fix = nil
        message = "Waiting for a location signal…"
    }
    #if targetEnvironment(simulator)
    private func readMac() {
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try? Data().write(to: cache.appendingPathComponent("location-request"))
        guard let data = try? Data(contentsOf: cache.appendingPathComponent("mac-location")),
              let packet = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let t = packet["time"] as? Double, abs(Date().timeIntervalSince1970 - t) < 60 else {
            fix = nil; message = "Waiting for Mac location…"; return
        }
        guard let lat = packet["lat"] as? Double, let lon = packet["lon"] as? Double, let accuracy = packet["accuracy"] as? Double else {
            fix = nil; message = packet["status"] as? String ?? "Waiting for Mac location…"; return
        }
        fix = CLLocation(coordinate: .init(latitude: lat, longitude: lon), altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1, timestamp: Date(timeIntervalSince1970: t))
    }
    #endif
}

private struct PeopleDirectory: Identifiable {
    let id = UUID()
    let title: String
    let people: [DateProfile]
}

// 180 attendees including the viewer; only these 120 fictional attendees opted in.
private enum DemoCrowd {
    static let people: [DateProfile] = DateProfile.examples + (0..<117).map { i in
        let names = "Alex Maya Leo Zoe Kai Mina Theo Nina Luca Iris Owen Eva Finn Ada Max Lia Nico Tess Eli June Beau Hana Milo Sana Ravi Mira Rowan Olive Ezra Wren".components(separatedBy: " ")
        let suffix = ["A.", "B.", "C.", "D."][i / names.count]
        let interests = DateProfile.choices
        let first = i % interests.count
        let second = (first + 1 + (i / interests.count) % (interests.count - 1)) % interests.count
        let goals = ["Someone to explore with", "An adventure buddy", "A creative collaborator"]
        let id = UUID(uuidString: String(format: "10000000-0000-4000-A000-%012d", i))!
        return DateProfile(id: id, name: names[i % names.count] + " " + suffix,
                           interests: [interests[first], interests[second]],
                           lookingFor: goals[(i + i / interests.count) % goals.count],
                           occupation: ["Product designer", "Software engineer", "Illustrator", "Event producer", "Researcher", "Architect"][i % 6],
                           education: ["BFA in Design", "BS in Computer Science", "BA in Fine Arts", "BA in Communications", "MSc in Biology", "Master of Architecture"][i % 6], symbol: "sparkles")
    }
    static let indices = Dictionary(uniqueKeysWithValues: people.enumerated().map { ($0.element.id, $0.offset) })
}

private struct DeviceMap: View {
    let people: [DateProfile]
    let compatible: Set<UUID>
    let showGroup: ([DateProfile]) -> Void
    @StateObject private var position = DevicePosition()
    @State private var anchor: CLLocationCoordinate2D?
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        VStack(alignment: .leading) {
            if let fix = position.fix {
                Map(position: $camera) {
                    Annotation("", coordinate: fix.coordinate) { MyAvatar() }
                    if let anchor {
                        ForEach(0..<6, id: \.self) { index in
                            let members = people.filter { (DemoCrowd.indices[$0.id] ?? 0) % 6 == index }
                            if let first = members.first(where: { compatible.contains($0.id) }) ?? members.first {
                                let angle = Double(index) * .pi / 3
                                let spot = CLLocationCoordinate2D(latitude: anchor.latitude + 16 * cos(angle) / 111_000,
                                                                  longitude: anchor.longitude + 17 * sin(angle) / (111_000 * max(0.01, cos(anchor.latitude * .pi / 180))))
                                Annotation("", coordinate: spot) {
                                    Button { showGroup(members) } label: {
                                        ProfilePortrait(person: first, size: 38)
                                            .overlay(alignment: .topTrailing) {
                                                if compatible.contains(first.id) {
                                                    Image(systemName: "heart.fill")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(.pink)
                                                        .frame(width: 17, height: 17)
                                                        .background(.white, in: Circle())
                                                        .offset(x: 3, y: -2)
                                                        .accessibilityHidden(true)
                                                }
                                            }
                                            .overlay(alignment: .bottomTrailing) {
                                                Text("\(members.count)").font(.caption2.bold()).padding(3)
                                                    .foregroundStyle(.white).background(.black, in: Capsule()).offset(x: 6, y: 3)
                                            }
                                    }.accessibilityLabel("\(first.name), \(compatible.contains(first.id) ? "high compatibility, " : "")\(members.count) people here")
                                }
                            }
                        }
                    }
                }.frame(height: 340).clipShape(RoundedRectangle(cornerRadius: 18))
                Text("Your location ±\(Int(fix.horizontalAccuracy.rounded())) m · \(people.count) open · 180 demo attendees").font(.footnote)
            } else {
                Label(position.message, systemImage: "location").frame(maxWidth: .infinity, minHeight: 190)
            }
        }.onAppear { position.start() }.onDisappear { position.stop() }
            .onChange(of: position.fix) { _, new in
                guard let fix = new else { return }
                if anchor == nil { anchor = fix.coordinate }
                camera = .region(MKCoordinateRegion(center: fix.coordinate, latitudinalMeters: 56, longitudinalMeters: 56))
            }
    }
}

private struct MatchDatePlanner: View {
    let person: DateProfile
    let demo: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date?
    @State private var place = ""
    @State private var confirmed = false
    private let pink = Color(red: 1, green: 0.65, blue: 0.84)
    var followUpID: String? = nil
    private var key: String { "openDate.datePlan." + person.id.uuidString + (followUpID.map { "." + $0 } ?? "") }

    private func prepare() async {
        let defaults = UserDefaults.standard
        if let saved = defaults.dictionary(forKey: key),
           let date = saved["time"] as? Date, let venue = saved["place"] as? String {
            time = date
            place = venue
            confirmed = saved["confirmed"] as? Bool ?? false
            return
        }
        let calendar = Calendar.current
        let now = Date()
        let reserved = defaults.dictionaryRepresentation().compactMap { entry -> Date? in
            guard entry.key.hasPrefix("openDate.datePlan.") else { return nil }
            return (entry.value as? [String: Any])?["time"] as? Date
        }
        // Prefer the first evening slot with enough notice and no overlap with a local date plan.
        let slots = (0...(reserved.count + 1)).flatMap { offset -> [Date] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return [] }
            return [18, 19, 20].compactMap { calendar.date(bySettingHour: $0, minute: 0, second: 0, of: day) }
        }
        let candidate = slots.first { slot in
            slot.timeIntervalSince(now) >= 7200 && reserved.allSatisfy { abs($0.timeIntervalSince(slot)) >= 7200 }
        }
        do { try await Task.sleep(for: .seconds(2.4)) } catch { return }
        guard let candidate else { return }
        place = demo ? "Ruby Wine, Potrero Hill" : "Choose a meeting place together"
        time = candidate
        defaults.set(["place": place, "time": candidate, "confirmed": false], forKey: key)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.07, blue: 0.17), Color(red: 0.19, green: 0.11, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        ProfilePortrait(person: person, size: 40)
                        Text("Date with " + person.name).font(.headline)
                        Spacer()
                        Button("Done") { dismiss() }.foregroundStyle(pink)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        if let time {
                            Text(confirmed ? "Date set" : followUpID == nil ? "First date" : "Next date").font(.subheadline.bold()).foregroundStyle(pink)
                            Text(time.formatted(.dateTime.weekday(.wide)) + " · " + time.formatted(date: .omitted, time: .shortened))
                                .font(.system(.largeTitle, design: .serif).bold())
                            Text(time.formatted(date: .long, time: .omitted)).font(.subheadline)
                            Divider()
                            LabeledContent(place, value: "For two")
                            Divider()
                            LabeledContent("Suggested departure", value: time.addingTimeInterval(-1200).formatted(date: .omitted, time: .shortened))
                            Divider()
                            LabeledContent(person.name, value: demo ? "Demo match" : "Awaiting confirmation")
                            Button {
                                confirmed = true
                                UserDefaults.standard.set(["place": place, "time": time, "confirmed": true], forKey: key)
                            } label: {
                                Text(confirmed ? "Confirmed by you" : "Confirm").fontWeight(.semibold).frame(maxWidth: .infinity).padding(12)
                            }.background(pink, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.black).disabled(confirmed)
                        } else {
                            ProgressView().tint(pink)
                            Text("Finding a time for two…").font(.system(.title, design: .serif).bold())
                        }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))
                    Text(demo ? "Demo itinerary · No bookings or invitations." : "Saved on this device. Confirm with your match before booking.").font(.footnote).foregroundStyle(.white.opacity(0.72))
                }.padding(20)
            }
        }.foregroundStyle(.white).task { await prepare() }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}

private struct ReviewDate: Identifiable {
    let id: String
    let person: DateProfile
    let time: Date
    let place: String
}

private struct DateHistory: View {
    let dates: [ReviewDate]
    let demo: Bool

    static func load(people: [DateProfile], demo: Bool) -> [ReviewDate] {
        var history: [ReviewDate] = []
        for person in people {
            let prefix = "openDate.datePlan." + person.id.uuidString
            for (key, value) in UserDefaults.standard.dictionaryRepresentation() where key == prefix || key.hasPrefix(prefix + ".") {
                guard let plan = value as? [String: Any], plan["confirmed"] as? Bool == true,
                      let time = plan["time"] as? Date, time <= Date(), let place = plan["place"] as? String else { continue }
                history.append(ReviewDate(id: key, person: person, time: time, place: place))
            }
        }
        if demo, people.contains(where: { $0.id == DemoCrowd.people[3].id }) {
            let key = "openDate.sampleEncounterDate"
            let time = UserDefaults.standard.object(forKey: key) as? Date ?? Date().addingTimeInterval(-86400)
            UserDefaults.standard.set(time, forKey: key)
            history.append(ReviewDate(id: "sample-alex", person: DemoCrowd.people[3], time: time, place: "Record fair · Demo date"))
        }
        return history.sorted { $0.time > $1.time }
    }

    var body: some View {
            List {
                if dates.isEmpty { Text("After a confirmed date has passed, you can reflect on it here.") }
                ForEach(dates) { date in
                    NavigationLink {
                        DateDebrief(date: date, demo: demo)
                    } label: {
                        HStack(spacing: 12) {
                            ProfilePortrait(person: date.person, size: 50)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(date.person.name).font(.headline)
                                Text(date.place)
                                Text(date.time.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }.navigationTitle("Past dates")
    }
}

private struct DateDebrief: View {
    struct Reflection: Codable {
        var turns: [ReviewTurn] = []
        var idea: String?
        var rating = 0
        var interest = "Unsure"
        var verdict: DateVerdict?
        var transcript: String?
    }
    let date: ReviewDate
    let demo: Bool
    @State private var review: Reflection
    @State private var busy = false
    @State private var planning = false
    @State private var bothAgreed = false
    @State private var synced: Bool?
    @StateObject private var recorder = DateRecorder()
    @FocusState private var typing: Bool
    private var key: String { "openDate.review." + date.id }
    init(date: ReviewDate, demo: Bool) {
        self.date = date
        self.demo = demo
        let data = UserDefaults.standard.data(forKey: "openDate.review." + date.id)
        var stored = data.flatMap { try? JSONDecoder().decode(Reflection.self, from: $0) } ?? Reflection()
        if stored.idea == nil { stored.idea = stored.turns.map(\.note).joined(separator: "\n\n") }
        _review = State(initialValue: stored)
    }
    private func save() { UserDefaults.standard.set(try? JSONEncoder().encode(review), forKey: key) }
    private let pink = Color(red: 1, green: 0.66, blue: 0.84)
    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        ProfilePortrait(person: date.person, size: 42)
                        VStack(alignment: .leading) {
                            Text(date.person.name).font(.headline)
                            Text(date.place).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    recordCard
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Share your idea").font(.headline)
                        TextField("", text: Binding(get: { review.idea ?? "" }, set: {
                            review.idea = $0; review.verdict = nil; save()
                        }), prompt: Text("How did the date feel?").foregroundColor(.white.opacity(0.6)), axis: .vertical)
                            .lineLimit(3...6).focused($typing).accessibilityLabel("Share your idea")
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rate your date").font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
                            ForEach(1...10, id: \.self) { n in
                                Button {
                                    review.rating = n; review.verdict = nil; typing = false; save()
                                } label: {
                                    Text(String(n)).fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundStyle(n == review.rating ? Color.black : .white)
                                        .background(n == review.rating ? pink : .white.opacity(0.1), in: Capsule())
                                }.accessibilityLabel("\(n) out of 10").accessibilityAddTraits(n == review.rating ? .isSelected : [])
                            }
                        }
                    }.padding(18).background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                    Button {
                        typing = false
                        busy = true
                        Task {
                            review.verdict = await DateCoach.verdict([review.idea ?? "", review.transcript.map { "What we said on the date: " + $0 } ?? ""].filter { !$0.isEmpty }, rating: review.rating)
                            save(); busy = false
                            withAnimation { reader.scrollTo("summary", anchor: .center) }
                            if let v = review.verdict {
                                synced = await ConvexSync.saveReview(match: date.person.name, place: date.place, rating: review.rating,
                                    agentScore: v.score, summary: v.summary, next: v.next, recorded: review.transcript != nil)
                            }
                        }
                    } label: {
                        Text(busy ? "Summarizing…" : "Summarize Date").fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 48).foregroundStyle(.black)
                            .background(pink, in: RoundedRectangle(cornerRadius: 14))
                    }.disabled(review.rating == 0 || busy).opacity(review.rating == 0 ? 0.5 : 1)
                    if let result = review.verdict {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Date summary").font(.headline)
                            LabeledContent("Your rating", value: "\(review.rating) / 10")
                            LabeledContent(result.model ? "Your agent" : "Guided estimate", value: result.score.formatted(.number.precision(.fractionLength(1))) + " / 10")
                            Text(result.summary)
                            Divider()
                            Text(result.next)
                            if let synced { Label(synced ? "Saved to your Convex date history" : "Couldn't reach Convex, saved on this phone", systemImage: synced ? "checkmark.icloud" : "icloud.slash").font(.caption).foregroundStyle(.white.opacity(0.7)) }
                            if review.rating >= 6 { Button("Plan it") { planning = true }.foregroundStyle(pink) }
                        }.padding(18).background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18)).id("summary")
                    }
                }.padding(20).disabled(busy)
            }.scrollDismissesKeyboard(.interactively)
        }.background(LinearGradient(colors:[Color(red:0.10,green:0.07,blue:0.17),Color(red:0.19,green:0.11,blue:0.25)], startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea())
            .foregroundStyle(.white).navigationTitle("Analyze Date").navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for:.navigationBar)
            .sheet(isPresented:$planning) { MatchDatePlanner(person:date.person, demo:demo, followUpID: String(Int(date.time.timeIntervalSince1970))) }
            .onChange(of: recorder.transcript) { text in
                guard !text.isEmpty else { return }
                review.transcript = text; review.verdict = nil; save()
            }
            .onDisappear { recorder.stop() }
    }

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: recorder.recording ? "waveform" : "mic.fill").foregroundStyle(pink)
                Text("Record the date").font(.headline)
                Spacer()
                if recorder.recording {
                    Text(Duration.seconds(Int(recorder.elapsed)).formatted(.time(pattern: .minuteSecond)))
                        .font(.subheadline.monospacedDigit()).foregroundStyle(pink)
                }
            }
            Text("Transcribed on this iPhone. Audio is never saved.")
                .font(.footnote).foregroundStyle(.white.opacity(0.7))
            if !recorder.recording {
                Toggle(isOn: $bothAgreed) {
                    Text("We both agreed to record").font(.subheadline)
                }.tint(pink)
            }
            if recorder.recording {
                GeometryReader { g in
                    Capsule().fill(.white.opacity(0.12)).overlay(alignment: .leading) {
                        Capsule().fill(pink).frame(width: max(8, g.size.width * CGFloat(recorder.level)))
                    }
                }.frame(height: 6).animation(.easeOut(duration: 0.1), value: recorder.level)
            }
            Button {
                typing = false
                if recorder.recording { recorder.stop() } else { Task { await recorder.start() } }
            } label: {
                Label(recorder.recording ? "Stop recording" : "Start recording", systemImage: recorder.recording ? "stop.fill" : "record.circle")
                    .fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(recorder.recording ? .white : .black)
                    .background(recorder.recording ? Color.red.opacity(0.85) : pink, in: RoundedRectangle(cornerRadius: 14))
            }.disabled(!bothAgreed && !recorder.recording).opacity(!bothAgreed && !recorder.recording ? 0.5 : 1)
            Text(recorder.status).font(.caption).foregroundStyle(.white.opacity(0.6))
            if let text = review.transcript, !text.isEmpty {
                Divider().overlay(.white.opacity(0.2))
                Text("Transcript").font(.subheadline.bold())
                Text(text).font(.callout).textSelection(.enabled)
                if !recorder.recording {
                    Button("Delete transcript", role: .destructive) { review.transcript = nil; review.verdict = nil; save() }
                        .font(.footnote)
                }
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
    }
}
