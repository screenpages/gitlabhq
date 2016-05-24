require 'spec_helper'

describe Issue, "Issuable" do
  let(:issue) { create(:issue) }
  let(:user) { create(:user) }

  describe "Associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:author) }
    it { is_expected.to belong_to(:assignee) }
    it { is_expected.to have_many(:notes).dependent(:destroy) }
    it { is_expected.to have_many(:todos).dependent(:destroy) }
  end

  describe "Validation" do
    before do
      allow(subject).to receive(:set_iid).and_return(false)
    end

    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:iid) }
    it { is_expected.to validate_presence_of(:author) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_least(0).is_at_most(255) }
  end

  describe "Scope" do
    it { expect(described_class).to respond_to(:opened) }
    it { expect(described_class).to respond_to(:closed) }
    it { expect(described_class).to respond_to(:assigned) }
  end

  describe ".search" do
    let!(:searchable_issue) { create(:issue, title: "Searchable issue") }

    it 'returns notes with a matching title' do
      expect(described_class.search(searchable_issue.title)).
        to eq([searchable_issue])
    end

    it 'returns notes with a partially matching title' do
      expect(described_class.search('able')).to eq([searchable_issue])
    end

    it 'returns notes with a matching title regardless of the casing' do
      expect(described_class.search(searchable_issue.title.upcase)).
        to eq([searchable_issue])
    end
  end

  describe ".full_search" do
    let!(:searchable_issue) do
      create(:issue, title: "Searchable issue", description: 'kittens')
    end

    it 'returns notes with a matching title' do
      expect(described_class.full_search(searchable_issue.title)).
        to eq([searchable_issue])
    end

    it 'returns notes with a partially matching title' do
      expect(described_class.full_search('able')).to eq([searchable_issue])
    end

    it 'returns notes with a matching title regardless of the casing' do
      expect(described_class.full_search(searchable_issue.title.upcase)).
        to eq([searchable_issue])
    end

    it 'returns notes with a matching description' do
      expect(described_class.full_search(searchable_issue.description)).
        to eq([searchable_issue])
    end

    it 'returns notes with a partially matching description' do
      expect(described_class.full_search(searchable_issue.description)).
        to eq([searchable_issue])
    end

    it 'returns notes with a matching description regardless of the casing' do
      expect(described_class.full_search(searchable_issue.description.upcase)).
        to eq([searchable_issue])
    end
  end

  describe "#today?" do
    it "returns true when created today" do
      # Avoid timezone differences and just return exactly what we want
      allow(Date).to receive(:today).and_return(issue.created_at.to_date)
      expect(issue.today?).to be_truthy
    end

    it "returns false when not created today" do
      allow(Date).to receive(:today).and_return(Date.yesterday)
      expect(issue.today?).to be_falsey
    end
  end

  describe "#new?" do
    it "returns true when created today and record hasn't been updated" do
      allow(issue).to receive(:today?).and_return(true)
      expect(issue.new?).to be_truthy
    end

    it "returns false when not created today" do
      allow(issue).to receive(:today?).and_return(false)
      expect(issue.new?).to be_falsey
    end

    it "returns false when record has been updated" do
      allow(issue).to receive(:today?).and_return(true)
      issue.touch
      expect(issue.new?).to be_falsey
    end
  end

  describe '#subscribed?' do
    context 'user is not a participant in the issue' do
      before { allow(issue).to receive(:participants).with(user).and_return([]) }

      it 'returns false when no subcription exists' do
        expect(issue.subscribed?(user)).to be_falsey
      end

      it 'returns true when a subcription exists and subscribed is true' do
        issue.subscriptions.create(user: user, subscribed: true)

        expect(issue.subscribed?(user)).to be_truthy
      end

      it 'returns false when a subcription exists and subscribed is false' do
        issue.subscriptions.create(user: user, subscribed: false)

        expect(issue.subscribed?(user)).to be_falsey
      end
    end

    context 'user is a participant in the issue' do
      before { allow(issue).to receive(:participants).with(user).and_return([user]) }

      it 'returns false when no subcription exists' do
        expect(issue.subscribed?(user)).to be_truthy
      end

      it 'returns true when a subcription exists and subscribed is true' do
        issue.subscriptions.create(user: user, subscribed: true)

        expect(issue.subscribed?(user)).to be_truthy
      end

      it 'returns false when a subcription exists and subscribed is false' do
        issue.subscriptions.create(user: user, subscribed: false)

        expect(issue.subscribed?(user)).to be_falsey
      end
    end
  end

  describe "#to_hook_data" do
    let(:data) { issue.to_hook_data(user) }
    let(:project) { issue.project }


    it "returns correct hook data" do
      expect(data[:object_kind]).to eq("issue")
      expect(data[:user]).to eq(user.hook_attrs)
      expect(data[:object_attributes]).to eq(issue.hook_attrs)
      expect(data).to_not have_key(:assignee)
    end

    context "issue is assigned" do
      before { issue.update_attribute(:assignee, user) }

      it "returns correct hook data" do
        expect(data[:object_attributes]['assignee_id']).to eq(user.id)
        expect(data[:assignee]).to eq(user.hook_attrs)
      end
    end

    include_examples 'project hook data'
    include_examples 'deprecated repository hook data'
  end

  describe '#card_attributes' do
    it 'includes the author name' do
      allow(issue).to receive(:author).and_return(double(name: 'Robert'))
      allow(issue).to receive(:assignee).and_return(nil)

      expect(issue.card_attributes).
        to eq({ 'Author' => 'Robert', 'Assignee' => nil })
    end

    it 'includes the assignee name' do
      allow(issue).to receive(:author).and_return(double(name: 'Robert'))
      allow(issue).to receive(:assignee).and_return(double(name: 'Douwe'))

      expect(issue.card_attributes).
        to eq({ 'Author' => 'Robert', 'Assignee' => 'Douwe' })
    end
  end

  describe "votes" do
    before do
      author = create :user
      project = create :empty_project
      issue.notes.awards.create!(note: "thumbsup", author: author, project: project)
      issue.notes.awards.create!(note: "thumbsdown", author: author, project: project)
    end

    it "returns correct values" do
      expect(issue.upvotes).to eq(1)
      expect(issue.downvotes).to eq(1)
    end
  end

  describe ".with_label" do
    let(:project) { create(:project, :public) }
    let(:bug) { create(:label, project: project, title: 'bug') }
    let(:feature) { create(:label, project: project, title: 'feature') }
    let(:enhancement) { create(:label, project: project, title: 'enhancement') }
    let(:issue1) { create(:issue, title: "Bugfix1", project: project) }
    let(:issue2) { create(:issue, title: "Bugfix2", project: project) }
    let(:issue3) { create(:issue, title: "Feature1", project: project) }

    before(:each) do
      issue1.labels << bug
      issue1.labels << feature
      issue2.labels << bug
      issue2.labels << enhancement
      issue3.labels << feature
    end

    it 'finds the correct issue containing just enhancement label' do
      expect(Issue.with_label(enhancement.title)).to match_array([issue2])
    end

    it 'finds the correct issues containing the same label' do
      expect(Issue.with_label(bug.title)).to match_array([issue1, issue2])
    end

    it 'finds the correct issues containing only both labels' do
      expect(Issue.with_label([bug.title, enhancement.title])).to match_array([issue2])
    end
  end
end
