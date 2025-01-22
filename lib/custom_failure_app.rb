class CustomFailureApp < Devise::FailureApp
  def respond
    json_api_response
  end

  private

  def json_api_response
    Rails.logger.debug "##############################################"
    Rails.logger.debug  i18n_message 
    Rails.logger.debug "##############################################"
    Rails.logger.debug "##############################################"
    self.status = 401
    self.content_type = 'application/json'
    self.response_body = { error: i18n_message || 'Invalid credentials' }.to_json
  end
end
