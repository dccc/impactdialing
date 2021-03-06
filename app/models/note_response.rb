class NoteResponse < ActiveRecord::Base
  belongs_to :voter
  belongs_to :note
  belongs_to :call_attempt
  belongs_to :campaign

  scope :for, lambda{|note| where(["note_id = ?",note.id])}
  scope :for_notes, lambda{|note_ids| where("note_id in (?) ", note_ids)}

  def self.note_ids(campaign_id)
    NoteResponse.where({
      campaign_id: campaign_id
    }).uniq.order('note_id').pluck(:note_id)
  end

  def self.response_texts(note_ids, note_responses)
    note_responses ||= []
    responses = note_responses.each_with_object({}) do |response, memo|
      memo[response['note_id']] = response['response']
    end
    note_ids.map do |note_id|
      responses.has_key?(note_id) ? responses[note_id] : ""
    end
  end
end

# ## Schema Information
#
# Table name: `note_responses`
#
# ### Columns
#
# Name                   | Type               | Attributes
# ---------------------- | ------------------ | ---------------------------
# **`id`**               | `integer`          | `not null, primary key`
# **`voter_id`**         | `integer`          | `not null`
# **`note_id`**          | `integer`          | `not null`
# **`response`**         | `string(255)`      |
# **`call_attempt_id`**  | `integer`          |
# **`campaign_id`**      | `integer`          |
#
# ### Indexes
#
# * `call_attempt_id`:
#     * **`call_attempt_id`**
#     * **`id`**
# * `voter_id`:
#     * **`voter_id`**
#     * **`note_id`**
#
