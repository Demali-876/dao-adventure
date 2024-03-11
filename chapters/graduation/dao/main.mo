import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import MBT "canister:graduation_token";
import WP "canister:graduation_webpage";
import Types "types";
actor {

        type Result<A, B> = Result.Result<A, B>;
        type Member = Types.Member;
        type ProposalContent = Types.ProposalContent;
        type ProposalId = Types.ProposalId;
        type Proposal = Types.Proposal;
        type Vote = Types.Vote;
        type HttpRequest = Types.HttpRequest;
        type HttpResponse = Types.HttpResponse;

        // The principal of the Webpage canister associated with this DAO canister (needs to be updated with the ID of your Webpage canister)
        stable let canisterIdWebpage : Principal = Principal.fromText("zneqq-taaaa-aaaab-qaccq-cai");
        stable var manifesto = "Let's graduate!";
        stable let name = "Test Dao";
        var goals = Buffer.Buffer<Text>(0);

        // Returns the name of the DAO
        public query func getName() : async Text {
                return name;
        };
        // Returns the manifesto of the DAO
        public query func getManifesto() : async Text {
                return manifesto;
        };
        public func _setManifesto(newManifesto : Text) : async () {
        manifesto := newManifesto;
        return;
        };
        func toNat32(n: Nat) : Nat32 {
        // Simple conversion, suitable for Nat values that fit within Nat32
        // For larger values, consider a different hashing approach
        return Nat32.fromNat(n);
        };
        public func addGoal(newGoal : Text) : async () {
        goals.add(newGoal);
        return;
        };

        // Returns the goals of the DAO
        public query func getGoals() : async [Text] {
                Buffer.toArray(goals);
        };
        // Register a new member in the DAO with the given name and principal of the caller
        // Airdrop 10 MBC tokens to the new member
        // New members are always Student
        // Returns an error if the member already exists
        let members = HashMap.HashMap<Principal, Member>(0, Principal.equal, Principal.hash);
        let initialMentorP = Principal.fromText("nkqop-siaaa-aaaaj-qa3qq-cai");
        let initialMentor: Member = {
            name = "motoko_bootcamp";
            role = #Mentor;
        };
        members.put(initialMentorP, initialMentor);

        private func mintTokensToInitialMentor() : async () {
        let mintResult = await MBT.mint(initialMentorP, 50);
        switch (mintResult) {
                case (#ok()) {// Minting succeeded
                        };
                case (#err(e)) {// Error
                        };
                };
        };
        public shared func init() : async () {
        await mintTokensToInitialMentor();
        };
        public shared ({ caller }) func registerMember(name : Text) : async Result<(), Text> {
        switch (members.get(caller)) {
            case (null) {
                // New member creation with the role of Student
                let newMember : Member = {
                    name = name;
                    role = #Student;
                };
                members.put(caller, newMember); // Adding the new member
                // Attempt to mint 10 MBC tokens for the new member
                let mintResult = await MBT.mint(caller, 10);
                switch (mintResult) {
                    case (#ok()) {
                        return #ok(); // Successfully minted tokens and registered member
                    };
                    case (#err(e)) {
                        return #err("Failed to mint tokens"); // Handle error
                    };
                };
            };
            case (?member) {
                return #err("Member already exists"); // Member already exists
                        };
                };
        };

        // Get the member with the given principal
        // Returns an error if the member does not exist
        public query func getMember(p : Principal) : async Result<Member, Text> {
                switch (members.get(p)) {
                        case (null) {
                                return #err("Member does not exist");
                        };
                        case (?member) {
                                return #ok(member);
                        };
                };
        };

        // Graduate the student with the given principal
        // Returns an error if the student does not exist or is not a student
        // Returns an error if the caller is not a mentor
        public shared ({ caller }) func graduate(student : Principal) : async Result<(), Text> {
                let isMentor = switch (members.get(caller)) {
                case (null) { false };
                case (?member) {
                        switch (member.role) {
                                case (#Mentor) { true };
                                case _ { false };
                                };
                        };
                };
                if (not isMentor) {
                return #err("Caller is not authorized as a mentor.");
                };

                return switch (members.get(student)) {
                case (null) { #err("Member does not exist."); };
                case (?member) {
                switch (member.role) {
                        case (#Student) {
                        members.put(student, {name = member.name; role = #Graduate});
                        #ok();
                        };
                        case _ { #err("Member is not a student."); };
                                };
                        };
                };
        };

        // Create a new proposal and returns its id
        // Returns an error if the caller is not a mentor or doesn't own at least 1 MBC token
        var nextProposalId : Nat = 0;
        let proposals = HashMap.HashMap<ProposalId, Proposal>(0, Nat.equal, toNat32);
        public shared ({ caller }) func createProposal(content : ProposalContent) : async Result<ProposalId, Text> {
        switch (members.get(caller)) {
                case (null) {
                return #err("The caller is not a member - cannot create a proposal");
                };
                case (?member) {
                switch (member.role) {
                        case (#Mentor) {
                        let balance: Nat = await MBT.balanceOf(caller);
                        if (balance < 1) {
                                return #err("The caller does not have enough tokens to create a proposal");
                        };
                        switch (await MBT.burn(caller, 1)) {
                                case (#ok()) {
                                let proposal: Proposal = {
                                        id = nextProposalId;
                                        content;
                                        creator = caller;
                                        created = Time.now();
                                        executed = null;
                                        votes = [];
                                        voteScore = 0;
                                        status = #Open;
                                };
                                proposals.put(nextProposalId, proposal);
                                nextProposalId += 1;
                                return #ok(nextProposalId - 1);
                                };
                                case (#err(e)) {
                                return #err("Failed to burn tokens");
                                        };
                                };
                        };
                        case _ {
                        return #err("Only mentors are authorized to create proposals");
                                };
                        };
                };
        };
        };

        // Get the proposal with the given id
        // Returns an error if the proposal does not exist
        public query func getProposal(id: ProposalId) : async Result<Proposal, Text> {
        switch (proposals.get(id)) {
                case (null) {
                return #err("Proposal does not exist.");
                };
                case (?proposal) {
                        return #ok(proposal);
                        };
                };
        };

        // Returns all the proposals
        public query func getAllProposals() : async [Proposal] {
        return Iter.toArray(proposals.vals());
        };

        // Vote for the given proposal
        // Returns an error if the proposal does not exist or the member is not allowed to vote
        public shared ({ caller }) func voteProposal(proposalId : ProposalId, yesOrNo : Bool) : async Result<(), Text> {
        // Check if the caller is a member of the DAO
        switch (members.get(caller)) {
                case (null) {
                return #err("The caller is not a member - cannot vote on proposal");
                };
                case (?member) {
                // Check if the proposal exists
                switch (proposals.get(proposalId)) {
                        case (null) {
                        return #err("The proposal does not exist");
                        };
                        case (?proposal) {
                        // Check if the proposal is open for voting
                        if (proposal.status != #Open) {
                                return #err("The proposal is not open for voting");
                        };
                        // Check if the caller has already voted
                        if (_hasVoted(proposal, caller)) {
                                return #err("The caller has already voted on this proposal");
                        };
                        let callerBalance = await MBT.balanceOf(caller); // Correctly retrieve the caller's token balance
                        let votingPower: Nat = switch (member.role) { // Use 'member.role' directly
                                case (#Student) { 0 };
                                case (#Graduate) { callerBalance };
                                case (#Mentor) { 5 * callerBalance };
                        };
                        if (votingPower == 0) {
                                return #err("Caller does not have voting rights.");
                        };
                        let voteEffect = if (yesOrNo) { votingPower } else { -votingPower };
                        let newVoteScore = proposal.voteScore + voteEffect;
                        let newStatus = 
                                if (newVoteScore >= 100) { #Accepted }
                                else if (newVoteScore <= -100) { #Rejected }
                                else { proposal.status };

                        var newVotes = Buffer.fromArray<Vote>(proposal.votes);
                        newVotes.add({member = caller; votingPower= votingPower; yesOrNo = yesOrNo});

                        // Determine if the proposal is executed and update the execution time
                        var newExecuted : ?Time.Time = proposal.executed;
                        if (newStatus == #Accepted) {
                                await _executeProposal(proposal);
                                newExecuted := ?Time.now();
                        };

                        let newProposal : Proposal = {
                                id = proposal.id;
                                content = proposal.content;
                                creator = proposal.creator;
                                created = proposal.created;
                                executed = newExecuted;
                                votes = Buffer.toArray(newVotes);
                                voteScore = newVoteScore;
                                status = newStatus;
                        };

                        proposals.put(proposalId, newProposal); // Update the proposal in the HashMap
                        return #ok();
                                };
                        };
                        };
                };
        };

        // Returns the Principal ID of the Webpage canister associated with this DAO canister
        public query func getIdWebpage() : async Principal {
                return canisterIdWebpage;
        };
        func _hasVoted(proposal : Proposal, member : Principal) : Bool {
        return Array.find<Vote>(
            proposal.votes,
            func(vote : Vote) {
                return vote.member == member;
            },
        ) != null;
        };

        private func _executeProposal(proposal: Proposal) : async () {
        switch (proposal.content) {
                case (#ChangeManifesto(newManifesto)) {
                await _setManifesto(newManifesto);
                let setResult = await WP.setManifesto(newManifesto);
                switch (setResult) {
                        case (#ok()) { /*Succes */};
                        case (#err(errMsg)) {/*Error*/ };
                };
                };
                case (#AddMentor(principal)) {
                switch (members.get(principal)) {
                        case (null) { /* No action required */ };
                        case (?member) {
                        if (member.role == #Graduate) {
                                members.put(principal, {name = member.name; role = #Mentor;});
                        };
                        };
                };
                };
                case(#AddGoal(newGoal)){
                        goals.add(newGoal);
                };
        };
        };
};