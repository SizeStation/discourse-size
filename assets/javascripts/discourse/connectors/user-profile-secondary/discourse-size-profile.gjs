import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import formatSize from "../../helpers/format-size";

<template>
  {{#if @outletArgs.model.discourse_size_main_character}}
    {{#let @outletArgs.model.discourse_size_main_character as |char|}}
      <div class="discourse-size-profile-widget">
        <div class="ds-profile-name">
          {{icon "paw"}}
          <a
            href="/u/{{@outletArgs.model.username}}/characters"
          >{{char.name}}</a>
        </div>
        <div class="ds-profile-size">
          {{formatSize char.current_size char.measurement_system}}
        </div>
        {{#if char.is_growing}}
          <div class="ds-profile-status growing">
            {{icon "arrow-up"}}{{i18n "discourse_size.growing"}}
          </div>
        {{else if char.is_shrinking}}
          <div class="ds-profile-status shrinking">
            {{icon "arrow-down"}}{{i18n "discourse_size.shrinking"}}
          </div>
        {{/if}}
      </div>
    {{/let}}
  {{/if}}
</template>
