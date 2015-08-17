require 'rails_helper'

def voter_system_fields
  %w(first_name last_name middle_name suffix email address city state zip_code country)
end

describe 'CallFlow::Jobs::Persistence::DialedCall' do
  include ListHelpers

  let(:account){ create(:account) }
  let(:campaign){ create(:power, account: account) }
  let(:voter_list){ create(:voter_list, campaign: campaign) }
  let(:caller_session){ create(:webui_caller_session, campaign: campaign, sid: 'caller-session-sid') }
  let(:households) do
    hh = build_household_hashes(1, voter_list)
    hh.each do |phone,data|
      hh[phone][:leads] = data[:leads].map{|lead| lead[:uuid] = UUID.new.generate; lead}
    end
    hh
  end
  let(:phone){ households.keys.first }
  let(:callback_params) do
    # params from twilio when Url to POST /Calls requested
    {
      campaign_type: campaign.type,
      campaign_id: campaign.id,
      event: 'incoming_call',
      phone: households.keys.first
    }
  end

  let(:completed_params) do
    # params from twilio when status callback endpoint requested
    HashWithIndifferentAccess.new({
      AccountSid: 'AC422d17e57a30598f8120ee67feae29cd',
      CallSid: 'CA927ee0a4dc334de8495b6470c2b322b4',
      ToZip: '97204',
      FromState: '',
      Called: '+19712642814',
      FromCountry: '',
      CallerCountry: '',
      CalledZip: '97204',
      Direction: 'outbound-api',
      FromCity: '',
      CalledCountry: 'US',
      CallerState: '',
      CalledState: 'OR',
      From: '+15555551234',
      CallerZip: '',
      FromZip: '',
      ToCity: 'PORTLAND',
      ToState: 'OR',
      To: '+19712642814',
      ToCountry: 'US',
      CallerCity: '',
      ApiVersion: '2010-04-01',
      Caller: '+15555551234',
      CalledCity: 'PORTLAND',
      Timestamp: 'Fri, 07 Aug 2015 01:31:42 +0000',
      CallDuration: '29',
      CallStatus: 'completed'
    })
  end
  let(:not_answered_params) do
    # params from twilio when status callback endpoint requested
    HashWithIndifferentAccess.new({
      AccountSid: 'AC422d17e57a30598f8120ee67feae29cd',
      CallSid: 'CA040b963cfdd3ae1a8481a0b1fb0c2a90',
      CallStatus: 'busy',
      To: '+19712645346',
      Called: '+19712645346',
      CallDuration: '0',
      Timestamp: 'Fri, 07 Aug 2015 01:33:20 +0000',
      Direction: 'outbound-api',
      ApiVersion: '2010-04-01',
      SipResponseCode: '486',
      Caller: '+15555551234',
      From: '+15555551234'
    })
  end
  let(:redis){ Redis.new }
  let(:account_sid){ completed_params[:AccountSid] }

  subject{ CallFlow::Jobs::Persistence::DialedCall.new }

  before do
    import_list(voter_list, households, 'active', 'presented')
  end

  after do
    redis.flushall
  end

  shared_context 'dialed call setup' do
    let(:call_sid){ completed_params[:CallSid] }
    let(:create_params) do
      {
        'account_sid' => account_sid,
        'sid' => call_sid
      }
    end
    let(:dialed_call){ CallFlow::Call::Dialed.create(campaign, create_params, {caller_session_sid: caller_session.sid}) }
    let(:voter_record){ Voter.last }
  end

  shared_examples_for 'persistence of any first call outcome' do
    it 'creates a CallAttempt record' do
      expect{
        subject.perform(account_sid, call_sid)
      }.to change{
        CallAttempt.count
      }.by 1
    end

    it 'creates a Household record' do
      expect{
        subject.perform(account_sid, call_sid)
      }.to change{
        Household.count
      }.by 1
    end

    describe 'the CallAttempt record' do
      let(:household_record){ Household.last }
      let(:household_status){ household_record.status }
      let(:voter_record_query){ Voter.where(status: household_status) }
      let(:voter_record){ voter_record_query.first }
      let(:call_attempt_record){ CallAttempt.last }
      before do
        subject.perform(account_sid, call_sid)
      end
      it 'associated w/ proper Household record' do
        expect(call_attempt_record.household).to eq household_record
      end
      it 'associated w/ proper Campaign record' do
        expect(call_attempt_record.campaign).to eq campaign
      end
      it 'associated w/ proper Voter record (when dispositioned)' do
        expect(call_attempt_record.voter).to eq voter_record
      end
      it 'associated w/ proper CallerSession record (when dispositioned)' do
        expect(call_attempt_record.caller_session).to eq caller_session
      end
      it 'associated w/ proper Caller record (when dispositioned)' do
        expect(call_attempt_record.caller).to eq caller_session.caller
      end
      it 'w/ mapped call status' do
        expect(call_attempt_record.status).to eq expected_household_status
      end
      it 'w/ sid' do
        expect(call_attempt_record.sid).to eq call_sid
      end
      it 'w/ dialer_mode' do
        expect(call_attempt_record.dialer_mode).to eq campaign.type
      end
    end

    describe 'the Household record' do
      let(:household_record){ Household.last }
      before do
        subject.perform(account_sid, call_sid)
      end
      it 'associated w/ proper Account record' do
        expect(household_record.account).to eq account
      end
      it 'associated w/ proper Campaign record' do
        expect(household_record.campaign).to eq campaign
      end
      it 'w/ dialed phone' do
        expect(household_record.phone).to eq households.keys.first
      end
      it 'w/ mapped call status' do
        expect(household_record.status).to eq expected_household_status
      end
    end

    describe 'the Voter record(s)' do
      before do
      end
      it 'associated w/ created Household record' do
        subject.perform(account_sid, call_sid)
        expect(voter_record.household).to eq Household.last
      end
      it 'associated w/ proper Account record' do
        subject.perform(account_sid, call_sid)
        expect(voter_record.account).to eq account
      end
      it 'associated w/ proper Campaign record' do
        subject.perform(account_sid, call_sid)
        expect(voter_record.campaign).to eq campaign
      end
      it 'associated w/ proper VoterList record' do
        subject.perform(account_sid, call_sid)
        expect(voter_record.voter_list).to eq voter_list
      end
      it 'w/ mapped call status' do
        subject.perform(account_sid, call_sid)
        expect(voter_record.status).to eq expected_lead_status
      end
      it 'stores its SQL ID with redis lead data' do
        expect(Wolverine.dial_queue).to receive(:update_leads_with_sql_id)
        subject.perform(account_sid, call_sid)
      end

      voter_system_fields.each do |field|
        it "w/ #{field}" do
          subject.perform(account_sid, call_sid)
          expect(voter_record[field]).to eq households[phone][:leads].last[field.to_sym]
        end
      end
    end
  end

  context 'the first dialed call to a given phone' do
    include_context 'dialed call setup'

    before do
      dialed_call.storage.save(dialed_call.send(:params_for_update, callback_params))
    end

    context 'when twilio call status is not "completed"' do
      include_context 'dialed call setup' do
        let(:call_sid){ not_answered_params[:CallSid] }
      end

      let(:expected_household_status){ CallAttempt::Status::MAP[not_answered_params[:CallStatus]] }
      let(:expected_lead_status){ Voter::Status::NOTCALLED }

      before do
        dialed_call.storage.save(dialed_call.send(:params_for_update, not_answered_params)) # overwrite status
      end

      it_behaves_like 'persistence of any first call outcome'
    end

    context 'when twilio call status was "completed"' do
      include_context 'dialed call setup' do
        let(:call_sid){ completed_params[:CallSid] }
      end

      let(:voter_record){ Voter.first }
      let(:dispositioned_lead){ households[phone][:leads].last }
      let(:expected_household_status){ CallAttempt::Status::MAP[completed_params[:CallStatus]] }
      let(:expected_lead_status){ expected_household_status }

      before do
        dialed_call                      = CallFlow::Call::Dialed.new(account_sid, call_sid)
        dialed_call.storage.save(dialed_call.send(:params_for_update, completed_params))
        dialed_call.storage['lead_uuid'] = dispositioned_lead[:uuid]
      end

      it_behaves_like 'persistence of any first call outcome'

      it 'each Voter record not associated w/ dialed call imports w/ status Voter::Status::NOTCALLED' do
        subject.perform(account_sid, call_sid)
        expect(Voter.where(status: Voter::Status::NOTCALLED).count).to eq households[phone][:leads].size - 1   
      end

      context 'the Voter record associated w/ dialed call' do
        let(:household_status){ Household.last.status }
        let(:voter_record_query){ Voter.where(status: household_status) }
        let(:voter_record){ voter_record_query.first }

        before do
          subject.perform(account_sid, call_sid)
        end

        it 'imports the correct lead data associated w/ the disposition' do
          voter_system_fields.each do |field|
            expect(voter_record[field]).to eq dispositioned_lead[field.to_sym]
          end
        end
        it 'inherits the Household status' do
          expect(Voter.where(status: household_status).count).to eq 1
        end
      end
    end

    context 'when dialed call was not answered (eg busy, no-answer, failed, abandoned, etc)' do
      let(:household_status){ Household.last.status }
      before do
        dialed_call = CallFlow::Call::Dialed.create(campaign, create_params, {caller_session_sid: caller_session.sid})
        dialed_call.storage.save(dialed_call.send(:params_for_update, not_answered_params))
        dialed_call.storage.save(dialed_call.send(:params_for_update, callback_params))
      end
      it 'each Voter record has default status of notcalled' do
        subject.perform(account_sid, call_sid)
        expect(Voter.where(status: Voter::Status::NOTCALLED).count).to eq households[phone][:leads].size
      end
    end
  end

  shared_examples_for 'persistence of any subsequently dialed call (to same phone)' do
    describe 'updating Household record' do
      let(:household){ campaign.households.where(phone: phone).first }

      it 'w/ mapped call status' do
        expect(household.status).to eq CallAttempt::Status::MAP[not_answered_params[:CallStatus]]
      end
    end

    describe 'updating Voter record(s)' do
      it 'dispositioned w/out retry Voter records retain status from previous call' do
        expect(Voter.where(status: CallAttempt::Status::SUCCESS).count).to eq 1
      end

      context 'incomplete Voter records (ie not dispositioned or will be retried)' do
        it 'inherit Household status'
      end
    end
  end

  context 'subsequent dialed calls to a given phone' do
    let(:account_sid){ completed_params[:AccountSid] }
    let(:call_sid){ completed_params[:CallSid] }
    let(:create_params) do
      {
        'account_sid' => account_sid,
        'sid' => call_sid
      }
    end
    let(:dispositioned_lead){ households[phone][:leads].last }
    let(:call_sid_two){ not_answered_params[:CallSid] }
    let(:create_params_two) do
      {
        'account_sid' => account_sid,
        'sid' => call_sid_two
      }
    end

    before do
      dialed_call = CallFlow::Call::Dialed.create(campaign, create_params, {caller_session_sid: caller_session.sid})
      dialed_call.storage.save(dialed_call.send(:params_for_update, callback_params))
      dialed_call.storage.save(dialed_call.send(:params_for_update, completed_params))
      dialed_call.storage['lead_uuid'] = dispositioned_lead[:uuid]
      subject.perform(account_sid, call_sid) # first call persistence (answered & lead dispositioned)
    end

    context 'when last dialed call was not answered' do
      before do
        dialed_call = CallFlow::Call::Dialed.create(campaign, create_params_two, {caller_session_sid: caller_session.sid})
        dialed_call.storage.save(dialed_call.send(:params_for_update, callback_params))
        dialed_call.storage.save(dialed_call.send(:params_for_update, not_answered_params))
        subject.perform(account_sid, call_sid_two) # second call persistence (not answered/busy)
      end

      it_behaves_like 'persistence of any subsequently dialed call (to same phone)'
    end

    context 'when last dialed call was answered' do
      it 'each Voter record not associated w/ dialed call are left untouched'

      context 'the Voter record associated w/ dialed call' do
        it 'inherits Household status'
        it 'associated w/ proper CallerSession'
      end
    end
  end
end

