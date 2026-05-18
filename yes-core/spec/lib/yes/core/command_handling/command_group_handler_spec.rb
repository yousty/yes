# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::CommandGroupHandler, integration: true do
  let(:aggregate_class) { Test::PersonalInfo::Aggregate }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:aggregate) { aggregate_class.new(aggregate_id) }
  let(:read_model) { aggregate.read_model }

  let(:valid_payload) do
    {
      first_name: 'Ada',
      last_name: 'Lovelace',
      email: 'ada@example.com',
      birth_date: '1815-12-10'
    }
  end

  describe '#call' do
    context 'when the group guard passes' do
      let!(:response) { aggregate.update_personal_info_group(**valid_payload) }

      it 'returns a successful CommandGroupResponse' do
        aggregate_failures do
          expect(response).to be_a(Yes::Core::Commands::CommandGroupResponse)
          expect(response).to be_success
        end
      end

      it 'publishes one event per sub-command, in declaration order' do
        event_types = response.events.map(&:type)
        expect(event_types).to eq([
                                    'Test::PersonalInfoNameChanged',
                                    'Test::PersonalInfoEmailChanged',
                                    'Test::PersonalInfoBirthDateChanged'
                                  ])
      end

      it 'updates the read model so it reflects the cumulative state' do
        read_model.reload
        aggregate_failures do
          expect(read_model.first_name).to eq('Ada')
          expect(read_model.last_name).to eq('Lovelace')
          expect(read_model.email).to eq('ada@example.com')
          expect(read_model.birth_date).to eq('1815-12-10')
        end
      end

      it 'persists exactly three events on the aggregate stream' do
        all_events = aggregate.events.to_a.flatten
        expect(all_events.size).to eq(3)
      end
    end

    context 'when the group guard fails (email blank)' do
      let(:invalid_payload) { valid_payload.merge(email: '') }
      let!(:response) { aggregate.update_personal_info_group(**invalid_payload) }

      it 'returns an error response with no published events' do
        aggregate_failures do
          expect(response).not_to be_success
          expect(response.error).to be_a(
            Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition
          )
          expect(response.events).to be_empty
          # Stream not created at all when guard fails before any publish
          expect { aggregate.latest_event }.to raise_error(PgEventstore::StreamNotFoundError)
        end
      end

      it 'does not touch the read model' do
        expect(read_model.reload.first_name).to be_blank
      end
    end

    context 'with guards: false (group guard bypassed)' do
      let!(:response) do
        aggregate.update_personal_info_group(**valid_payload, email: 'still-valid@example.com', guards: false)
      end

      it 'still publishes all sub-events' do
        expect(response.events.size).to eq(3)
        expect(response).to be_success
      end
    end

    context 'when a sub-command would normally fail its guard (bypassed by the group)' do
      # change_email has a :valid_email guard requiring '@'. The group skips
      # this guard, so an `@`-containing but unusual email still passes through.
      let(:edge_payload) { valid_payload.merge(email: 'user+tag@sub.domain.example') }
      let!(:response) { aggregate.update_personal_info_group(**edge_payload) }

      it 'publishes all events without invoking sub-command guards' do
        aggregate_failures do
          expect(response).to be_success
          expect(response.events.size).to eq(3)
          expect(read_model.reload.email).to eq('user+tag@sub.domain.example')
        end
      end
    end

    context '#can_update_personal_info_group?' do
      it 'returns true for a valid payload' do
        expect(aggregate.can_update_personal_info_group?(valid_payload)).to be(true)
      end

      it 'returns false when the group guard would fail' do
        expect(aggregate.can_update_personal_info_group?(valid_payload.merge(email: ''))).to be(false)
      end
    end
  end
end
