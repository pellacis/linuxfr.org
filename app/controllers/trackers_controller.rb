# encoding: UTF-8
class TrackersController < ApplicationController
  before_filter :honeypot, :only => [:create]
  before_filter :authenticate_account!, :only => [:edit, :update, :destroy]
  before_filter :load_tracker, :only => [:show, :edit, :update, :destroy]
  after_filter  :marked_as_read, :only => [:show], :if => :account_signed_in?

  def index
    @attrs    = {"state" => "opened"}.merge(params[:tracker] || {})
    @order    = params[:order]
    @order    = "created_at" unless VALID_ORDERS.include?(@order)
    @trackers = Tracker.scoped
    if @order == "created_at"
      @trackers = @trackers.order("#{@order} DESC")
    else
      @trackers = @trackers.joins(:node).order("nodes.#{@order} DESC")
    end
    @tracker  = Tracker.new(@attrs.except("state"))
    @tracker.state = @attrs["state"]
    @trackers = @trackers.where(:state       => @tracker.state)       if @attrs["state"].present?
    @trackers = @trackers.where(:category_id => @tracker.category_id) if @attrs["category_id"].present?
    if @attrs["assigned_to_user_id"] == 0
      @trackers = @trackers.where(:assigned_to_user_id => nil)
    elsif @attrs["assigned_to_user_id"].present?
      @trackers = @trackers.where(:assigned_to_user_id => @tracker.assigned_to_user_id)
    end
    respond_to do |wants|
      wants.html
      wants.atom
    end
  end

  def comments
    @comments = Comment.published.joins(:node).where('nodes.content_type' => 'Tracker').order('created_at DESC').limit(20)
    respond_to do |wants|
      wants.atom
    end
  end

  def show
    enforce_view_permission(@tracker)
    path = tracker_path(@tracker)
    redirect_to path, :status => 301 if request.path != path
  end

  def new
    @tracker = Tracker.new
  end

  def create
    @tracker = Tracker.new
    @tracker.attributes = params[:tracker]
    @tracker.tmp_owner_id = current_user.try(:id)
    if !preview_mode && @tracker.save
      redirect_to @tracker, :notice => "Votre entrée a bien été créée dans le suivi"
    else
      @tracker.node = Node.new
      @tracker.valid?
      render :new
    end
  end

  def edit
    enforce_update_permission(@tracker)
    @tracker.assigned_to_user ||= current_user
  end

  def update
    enforce_update_permission(@tracker)
    @tracker.assign_attributes(params[:tracker], :without_protection => true)
    if !preview_mode && @tracker.save
      redirect_to trackers_url, :notice => "Entrée du suivi modifiée"
    else
      flash.now[:alert] = "Impossible d'enregistrer cette entrée de suivi" unless @tracker.valid?
      render :edit
    end
  end

  def destroy
    enforce_destroy_permission(@tracker)
    @tracker.mark_as_deleted
    redirect_to trackers_url, :notice => "Entrée du suivi supprimée"
  end

protected

  def honeypot
    honeypot = params[:tracker].delete(:pot_de_miel)
    render :nothing => true if honeypot.present?
  end

  def marked_as_read
    current_account.read(@tracker.node)
  end

  def load_tracker
    @tracker = Tracker.find(params[:id])
  end
end
