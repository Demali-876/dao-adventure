import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
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
        stable let canisterIdWebpage : Principal = Principal.fromText("aaaaa-aa");
        stable var manifesto = "Let's graduate!";
        stable let name = "Test Dao";
        stable var goals = ["Finish Bootcamp"];

        // Returns the name of the DAO
        public query func getName() : async Text {
                return name;
        };
        // Returns the manifesto of the DAO
        public query func getManifesto() : async Text {
                return manifesto;
        };

        // Returns the goals of the DAO
        public query func getGoals() : async [Text] {
                return goals;
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
        var nextProposalId : Nat64 = 0;
        let proposals = HashMap.HashMap<ProposalId, Proposal>(0, Nat64.equal, Nat64.toNat32);
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
                                case (#ok(_)) {
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
                return #err("Not implemented");
        };

        // Returns the Principal ID of the Webpage canister associated with this DAO canister
        public query func getIdWebpage() : async Principal {
                return canisterIdWebpage;
        };
};