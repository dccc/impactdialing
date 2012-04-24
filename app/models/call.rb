class Call < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  include LeadEvents
  
  has_one :call_attempt
  serialize :conference_history, Array
  delegate :connect_call, :to => :call_attempt
  delegate :abandon_call, :to => :call_attempt
  delegate :connect_lead_to_caller ,:to => :call_attempt
  delegate :end_answered_call, :to => :call_attempt
  delegate :end_unanswered_call, :to => :call_attempt
  delegate :end_running_call, :to => :call_attempt
  delegate :disconnect_call, :to => :call_attempt
  delegate :wrapup_call, :to => :call_attempt
  delegate :wrapup_call_and_stop, :to => :call_attempt
  
  delegate :process_answered_by_machine, :to => :call_attempt
  delegate :caller_not_available?, :to => :call_attempt
  delegate :caller_available?, :to => :call_attempt
  delegate :caller_session, :to=> :call_attempt
  delegate :campaign, :to=> :call_attempt
  
  
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :incoming_call, :to => :connected , :if => (:answered_by_human_and_caller_available?)
        event :incoming_call, :to => :abandoned , :if => (:answered_by_human_and_caller_not_available?)
        event :incoming_call, :to => :call_answered_by_machine , :if => (:answered_by_machine?)
        event :call_ended, :to => :abandoned
      end 
      
      state :connected do
        before(:always) {  connect_call }
        after(:success) { publish_voter_connected }
        event :hangup, :to => :hungup
        event :disconnect, :to => :disconnected
        
        response do |xml_builder, the_call|
          xml_builder.Dial :hangupOnStar => 'false', :action => flow_call_url(the_call, :host => Settings.host), :record=> campaign.account.record_calls do |d|
            d.Conference caller_session.session_key, :waitUrl => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
          end
        end
        
      end
      
      state :abandoned do
        before(:always) { abandon_call }
        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
        
      end
      
      state :call_answered_by_machine do
        before(:always) { process_answered_by_machine }
        after(:always) { publish_call_answered_by_machine }
        
        response do |xml_builder, the_call|
          xml_builder.Play campaign.recording.file.url if campaign.use_recordings?
          xml_builder.Hangup
        end
      end
      
      state :hungup do
        before(:always) { end_running_call }
        event :disconnect, :to => :disconnected
      end
      
      
      state :disconnected do
        
        before(:always) { disconnect_call }
        after(:success) { publish_voter_disconnected }
                
        event :call_ended, :to => :success, :if => :call_connected?
        event :call_ended, :to => :fail, :if => :call_did_not_connect?
        
        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
        
      end
      
      state :success do
        before(:always) { end_answered_call }        
        event :submit_result, :to => :wrapup_and_continue
        event :submit_result_and_stop, :to => :wrapup_and_stop
        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end        
      end
      
      state :wrapup_and_continue do 
        before(:always) { wrapup_call }
        after(:always)  { publish_continue_calling }      
      end
      
      state :wrapup_and_stop do
        before(:always) { wrapup_call_and_stop }        
      end
            
      
      state :fail do
        before(:always) { end_unanswered_call }
        after(:success) { publish_unanswered_call_ended }  
              
        response do |xml_builder, the_call|
          caller_session.nil? ? xml_builder.Hangup : caller_session.run(:start_conf)
        end
      end
      
      
      
  end 
  
  def run(event,render_twiml=true)
      send(event)
      render if render_twiml
  end
  
  def answered_by_machine?
    answered_by == "machine"
  end

  def answered_by_human_and_caller_not_available?
    answered_by == "human" && caller_not_available?
  end
  
  def answered_by_human_and_caller_available?
    answered_by == "human" && caller_available?
  end
  
  def call_did_not_connect?
    ["no-answer", "busy", "failed"].include?(call_status)
  end
  
  def call_connected?
    !call_did_not_connect?
  end
  
  
  
  
  
  
end  