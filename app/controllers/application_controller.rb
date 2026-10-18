class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing

  private

  # Every error response is { errors: [{ code:, message:, attribute: (optional) }] }.
  # Clients should branch on `code`; `message` is for humans.
  def render_errors(errors, status:)
    render json: { errors: errors }, status: status
  end

  def render_validation_errors(record)
    errors = record.errors.map { |e| { attribute: e.attribute, code: e.type, message: e.message } }
    render_errors(errors, status: :unprocessable_entity)
  end

  def not_found
    render_errors([{ code: :not_found, message: I18n.t('api_errors.not_found') }], status: :not_found)
  end

  def parameter_missing
    render_errors([{ code: :parameter_missing, message: I18n.t('api_errors.parameter_missing') }], status: :bad_request)
  end
end
