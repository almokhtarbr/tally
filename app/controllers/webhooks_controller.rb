class WebhooksController < ApplicationController
  include Authentication
  include Auditable

  before_action :set_project
  before_action :set_webhook, only: [ :edit, :update, :destroy, :toggle, :test ]

  def index
    @webhooks = @project.webhooks.order(created_at: :desc)
  end

  def new
    @webhook = @project.webhooks.build(event_names: [ "*" ])
    @available_events = available_events
  end

  def create
    @webhook = @project.webhooks.build(webhook_params)
    if @webhook.save
      audit!(@project, "webhook.create", "Added a webhook to #{@webhook.url}", webhook_id: @webhook.id)
      redirect_to project_webhooks_path(@project), notice: "Webhook created."
    else
      @available_events = available_events
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_events = available_events
  end

  def update
    if @webhook.update(webhook_params)
      redirect_to project_webhooks_path(@project), notice: "Webhook updated."
    else
      @available_events = available_events
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @webhook.destroy
    audit!(@project, "webhook.delete", "Removed the webhook to #{@webhook.url}", webhook_id: @webhook.id)
    redirect_to project_webhooks_path(@project), notice: "Webhook deleted."
  end

  def toggle
    @webhook.update!(active: !@webhook.active?)
    state = @webhook.active? ? "Enabled" : "Disabled"
    audit!(@project, "webhook.toggle", "#{state} the webhook to #{@webhook.url}", webhook_id: @webhook.id, active: @webhook.active?)
    redirect_to project_webhooks_path(@project), notice: "Webhook #{@webhook.active? ? 'enabled' : 'disabled'}."
  end

  def test
    WebhookDeliveryJob.perform_later(
      webhook_id: @webhook.id,
      event_name: "test",
      payload: { event: "test", message: "This is a test webhook from Tally.", timestamp: Time.current.iso8601 }
    )
    redirect_to project_webhooks_path(@project), notice: "Test webhook queued."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_webhook
    @webhook = @project.webhooks.find(params[:id])
  end

  def webhook_params
    params.require(:webhook).permit(:url, event_names: [])
  end

  def available_events
    [ "*" ] + @project.event_daily_rollups.distinct.pluck(:event_name).sort
  end
end
