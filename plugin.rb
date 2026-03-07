# frozen_string_literal: true

# name: discourse-size
# about: A plugin that tracks user size and points
# meta_topic_id: TODO
# version: 0.1.0
# authors: Midblep
# url: https://github.com/SizeStation/discourse-size
# required_version: 2.7.0

enabled_site_setting :size_enabled

module ::MyPluginModule
  PLUGIN_NAME = "size"
end

module ::DiscourseSize
  SIZE_CM_FIELD = "ds_size_cm"
  POINTS_FIELD = "ds_points"
  UNIT_PREF_FIELD = "ds_unit_preference"

  def self.size_cm_for(user)
    value = user.custom_fields[SIZE_CM_FIELD]
    (value || 0).to_i
  end

  def self.set_size_cm!(user, new_size_cm)
    user.custom_fields[SIZE_CM_FIELD] = new_size_cm.to_i
    user.save_custom_fields(true)
  end

  def self.points_for(user)
    value = user.custom_fields[POINTS_FIELD]
    (value || 0).to_i
  end

  def self.set_points!(user, value)
    user.custom_fields[POINTS_FIELD] = [value.to_i, 0].max
    user.save_custom_fields(true)
  end

  def self.adjust_points!(user, delta)
    set_points!(user, points_for(user) + delta.to_i)
  end

  def self.unit_preference_for(user)
    pref = user.custom_fields[UNIT_PREF_FIELD]
    pref = nil if pref.respond_to?(:empty?) && pref.empty?
    pref || (SiteSetting.respond_to?(:size_default_unit_preference) ? SiteSetting.size_default_unit_preference : "metric")
  end

  def self.formatted_size_for(user)
    cm = size_cm_for(user)
    return nil if cm <= 0

    if unit_preference_for(user) == "imperial"
      format_size_imperial(cm)
    else
      format_size_metric(cm)
    end
  end

  def self.format_size_metric(cm)
    return nil if cm <= 0

    if cm < 100
      "#{cm.round(1)} cm"
    elsif cm < 100_000
      meters = cm / 100.0
      "#{meters.round(2)} m"
    else
      km = cm / 100_000.0
      "#{km.round(3)} km"
    end
  end

  def self.format_size_imperial(cm)
    return nil if cm <= 0

    inches_total = cm / 2.54
    if inches_total < 12
      "#{inches_total.round(1)} in"
    elsif inches_total < 63_360
      feet = (inches_total / 12).floor
      inches = (inches_total - feet * 12).round(1)
      if inches.zero?
        "#{feet} ft"
      else
        "#{feet} ft #{inches} in"
      end
    else
      miles = inches_total / 63_360.0
      "#{miles.round(3)} mi"
    end
  end

  def self.change_size_with_points!(user, percent)
    percent = percent.to_i
    raise Discourse::InvalidParameters.new(:percent) if percent.zero?

    cost = percent.abs
    current_points = points_for(user)
    raise Discourse::InvalidAccess.new(I18n.t("discourse_size.not_enough_points")) if current_points < cost

    current_size = size_cm_for(user)
    factor = 1.0 + (percent / 100.0)
    new_size = (current_size * factor).round
    new_size = 0 if new_size.negative?

    set_size_cm!(user, new_size)
    adjust_points!(user, -cost)

    new_size
  end

  def self.transfer_points!(from_user:, to_user:, amount:, allow_overdraft_for_staff: false)
    amount = amount.to_i
    raise Discourse::InvalidParameters.new(:amount) if amount <= 0
    raise Discourse::InvalidParameters.new(:target) if from_user.id == to_user.id

    from_points = points_for(from_user)

    if from_points < amount && !(allow_overdraft_for_staff && from_user.staff?)
      raise Discourse::InvalidAccess.new(I18n.t("discourse_size.not_enough_points"))
    end

    set_points!(from_user, from_points - amount)
    adjust_points!(to_user, amount)
  end
end

require_relative "lib/my_plugin_module/engine"

after_initialize do
  # Register custom fields
  User.register_custom_field_type(::DiscourseSize::SIZE_CM_FIELD, :integer)
  User.register_custom_field_type(::DiscourseSize::POINTS_FIELD, :integer)
  User.register_custom_field_type(::DiscourseSize::UNIT_PREF_FIELD, :string)

  # Users can edit only unit preference via profile settings, not size or points.
  register_editable_user_custom_field ::DiscourseSize::UNIT_PREF_FIELD

  # Preload fields commonly used in serializers
  [
    ::DiscourseSize::SIZE_CM_FIELD,
    ::DiscourseSize::POINTS_FIELD,
    ::DiscourseSize::UNIT_PREF_FIELD,
  ].each do |field|
    User.preloaded_custom_fields << field unless User.preloaded_custom_fields.include?(field)
  end

  # Expose display size on user serializers (public)
  add_to_serializer(:user, :size_display) do
    ::DiscourseSize.formatted_size_for(object)
  end

  add_to_serializer(:user_card, :size_display) do
    ::DiscourseSize.formatted_size_for(object)
  end

  # Expose raw fields for current user only
  add_to_serializer(:current_user, :size_points) do
    ::DiscourseSize.points_for(object)
  end

  add_to_serializer(:current_user, :size_cm) do
    ::DiscourseSize.size_cm_for(object)
  end

  add_to_serializer(:current_user, :size_unit_preference) do
    object.custom_fields[::DiscourseSize::UNIT_PREF_FIELD] ||
      (SiteSetting.respond_to?(:size_default_unit_preference) ? SiteSetting.size_default_unit_preference : "metric")
  end

  # Also expose raw values to admin user serializer
  add_to_serializer(:admin_detailed_user, :size_cm) do
    ::DiscourseSize.size_cm_for(object)
  end

  add_to_serializer(:admin_detailed_user, :size_points) do
    ::DiscourseSize.points_for(object)
  end

  # Award points when users create posts (topics or replies)
  on(:post_created) do |post, _opts, user|
    next unless SiteSetting.size_enabled
    next unless SiteSetting.respond_to?(:size_points_enabled) ? SiteSetting.size_points_enabled : true
    next if user.blank?
    next if post.topic&.private_message?

    ::DiscourseSize.adjust_points!(user, SiteSetting.respond_to?(:size_points_per_post) ? SiteSetting.size_points_per_post.to_i : 1)
  end
end
