# frozen_string_literal: true

require 'spec_helper'

describe ResourceEvents::MergeIntoNotesService do
  def create_event(params)
    event_params = { action: :add, label: label, issue: resource,
                     user: user }

    create(:resource_label_event, event_params.merge(params))
  end

  def create_note(params)
    opts = { noteable: resource, project: project }

    create(:note_on_issue, opts.merge(params))
  end

  set(:project)  { create(:project) }
  set(:user)   { create(:user) }
  set(:resource) { create(:issue, project: project) }
  set(:label) { create(:label, project: project) }
  set(:label2) { create(:label, project: project) }
  let(:time) { Time.now }

  describe '#execute' do
    context 'when notes filter is present' do
      before do
        create_note(created_at: 4.days.ago)
        create_event(created_at: 3.days.ago)
      end

      it 'does not merge label events if user preference filter is set to "only comments"' do
        notes = described_class.new(resource, user, notes_filter: UserPreference::NOTES_FILTERS[:only_comments]).execute([])

        expect(notes).to be_empty
      end

      it 'merges label events if user preference filter is set to "all activity"' do
        notes = described_class.new(resource, user, notes_filter: UserPreference::NOTES_FILTERS[:all_activity]).execute([])

        expect(notes).to be_present
      end
    end

    it 'merges label events into notes in order of created_at' do
      note1 = create_note(created_at: 4.days.ago)
      note2 = create_note(created_at: 2.days.ago)
      event1 = create_event(created_at: 3.days.ago)
      event2 = create_event(created_at: 1.day.ago)

      notes = described_class.new(resource, user).execute([note1, note2])

      expected = [note1, event1, note2, event2].map(&:discussion_id)
      expect(notes.map(&:discussion_id)).to eq expected
    end

    it 'squashes events with same time and author into single note' do
      user2 = create(:user)

      create_event(created_at: time)
      create_event(created_at: time, label: label2, action: :remove)
      create_event(created_at: time, user: user2)
      create_event(created_at: 1.day.ago, label: label2)

      notes = described_class.new(resource, user).execute()

      expected = [
        "added #{label.to_reference} label and removed #{label2.to_reference} label",
        "added #{label.to_reference} label",
        "added #{label2.to_reference} label"
      ]

      expect(notes.count).to eq 3
      expect(notes.map(&:note)).to match_array expected
    end

    it 'fetches only notes created after last_fetched_at' do
      create_event(created_at: 4.days.ago)
      event = create_event(created_at: 1.day.ago)

      notes = described_class.new(resource, user,
                                  last_fetched_at: 2.days.ago.to_i).execute()

      expect(notes.count).to eq 1
      expect(notes.first.discussion_id).to eq event.discussion_id
    end
  end
end
