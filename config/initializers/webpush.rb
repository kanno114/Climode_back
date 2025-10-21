# frozen_string_literal: true

# WebPush configuration for push notifications
# Generate VAPID keys using:
#   Webpush.generate_key.to_json
#
# Then set the environment variables:
# - VAPID_PUBLIC_KEY
# - VAPID_PRIVATE_KEY
# - VAPID_SUBJECT (mailto:your-email@example.com or https://your-domain.com)
#
# The webpush gem uses these environment variables directly,
# so no configuration is needed here. This file is just for documentation.

