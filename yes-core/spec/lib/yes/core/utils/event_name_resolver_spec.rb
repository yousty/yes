# frozen_string_literal: true

RSpec.describe Yes::Core::Utils::EventNameResolver do
  describe '.call' do
    subject(:resolve_event_name) { described_class.call(command_name) }

    context 'when command name starts with a known verb' do
      {
        'ChangeLocation' => :location_changed,
        'AddUser' => :user_added,
        'RemovePermission' => :permission_removed,
        'EnableFeature' => :feature_enabled,
        'DisableNotifications' => :notifications_disabled,
        'ActivateAccount' => :account_activated,
        'DeactivateProfile' => :profile_deactivated,
        'OpenTicket' => :ticket_opened,
        'CloseSession' => :session_closed,
        'StartProcess' => :process_started,
        'StopService' => :service_stopped,
        'SubmitForm' => :form_submitted,
        'ApproveRequest' => :request_approved,
        'RejectApplication' => :application_rejected,
        'ConfirmBooking' => :booking_confirmed,
        'CancelOrder' => :order_cancelled,
        'CompleteTask' => :task_completed,
        'FailJob' => :job_failed,
        'ResolveIssue' => :issue_resolved,
        'ReopenCase' => :case_reopened,
        'ReactivateSubscription' => :subscription_reactivated
      }.each do |command, expected_event|
        context "with '#{command}' command" do
          let(:command_name) { command }

          it 'converts command to event name', :aggregate_failures do
            expect(resolve_event_name).to eq(expected_event)
          end
        end
      end
    end

    context 'when command name is a symbol' do
      let(:command_name) { :change_location }

      it 'converts command to event name', :aggregate_failures do
        expect(resolve_event_name).to eq(:location_changed)
      end
    end

    context 'when command name does not start with a known verb' do
      let(:command_name) { 'InvalidCommand' }

      it 'returns nil', :aggregate_failures do
        expect(resolve_event_name).to be_nil
      end
    end
  end
end
