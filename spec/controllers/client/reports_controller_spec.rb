require "spec_helper"

describe Client::ReportsController do
  let(:user) { Factory(:user) }

  before(:each) do
    login_as user
  end

  describe 'usage report' do
    let!(:from_time) { 5.minutes.ago }
    let!(:time_now) { Time.now }

    describe 'call attempts' do
      before(:each) do
        campaign = Factory(:campaign, :account => user.account)
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (10.minutes + 2.seconds), :tDuration => 10.minutes + 2.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (1.minutes + 3.seconds), :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (101.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (10.seconds), :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:transfer_attempt, connecttime: Time.now, call_end: Time.now + (10.minutes + 2.seconds), :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        Factory(:transfer_attempt, connecttime: Time.now, call_end: Time.now + (1.minutes + 20.seconds), :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, 5.minutes.ago) }
        get :usage, :id => campaign.id
      end
      it "billable minutes" do
        assigns(:campaign).lead_time(from_time, time_now).should == 113
      end

      it "billable voicemails" do
        assigns(:campaign).voicemail_time(from_time, time_now).should == 3
      end

      it "billable abandoned calls" do
        assigns(:campaign).abandoned_calls_time(from_time, time_now).should == 2
      end

      it "billable transfer calls" do
        assigns(:campaign).transfer_time(from_time, time_now).should == 13
      end


    end

    describe 'utilization' do

      before(:each) do
        campaign = Factory(:campaign, :account => user.account)
        Factory(:caller_session, starttime: Time.now, endtime: Time.now + (30.minutes + 2.seconds), :tDuration => 10.minutes + 2.seconds, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        Factory(:caller_session, starttime: Time.now, endtime: Time.now + (101.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (10.minutes + 10.seconds), wrapup_time: Time.now + (10.minutes + 40.seconds), :tDuration => 10.minutes + 2.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (101.minutes + 57.seconds), wrapup_time: Time.now + (102.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }
        Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :campaign => campaign).tap { |ca| ca.update_attribute(:created_at, from_time) }

        get :usage, :id => campaign.id
      end

      it "logged in caller session" do
        assigns(:campaign).time_logged_in(from_time, time_now).should == "132"
      end

      it "on call time" do
        assigns(:campaign).time_on_call(from_time, time_now).should == "113"
      end

      it "on wrapup time" do
        assigns(:campaign).time_in_wrapup(from_time, time_now).should == "2"
      end
      it "on hold time" do
        assigns(:campaign).time_onhold(from_time, time_now) == "19"
      end


      it "minutes" do
        assigns(:campaign).caller_time(from_time, time_now).should == 133
      end

    end
  end


  describe "download report" do

    it "pulls up report downloads page" do
      campaign = Factory(:campaign, script: Factory(:script))
      Delayed::Job.should_receive(:enqueue)
      get :download, :campaign_id => campaign.id, format: 'csv'
      response.should redirect_to 'http://test.host/client/reports'
    end

    it "sets the default date range according to the campaign's time zone" do
      time_zone = ActiveSupport::TimeZone.new("Pacific Time (US & Canada)")
      campaign = Factory(:campaign, script: Factory(:script), :time_zone => time_zone.name)
      Time.stub(:now => Time.utc(2012, 2, 13, 0, 0, 0))
      get :download_report, :campaign_id => campaign.id
      response.should be_ok
      assigns(:from_date).to_i.should == time_zone.local(2012, 2, 12, 0).to_i
      assigns(:to_date).to_i.should == time_zone.local(2012, 2, 12, 23, 59, 59).to_i
    end

  end

end
