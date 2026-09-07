import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import formatSize from "../../helpers/format-size";

@classNames("user-card-metadata-outlet", "discourse-size-user-card")
export default class DiscourseSizeUserCardConnector extends Component {
  <template>
    {{#if @outletArgs.user.discourse_size_main_character}}
      {{#let @outletArgs.user.discourse_size_main_character as |char|}}
        <div class="discourse-size-user-card">
          <span class="ds-card-name">
            {{icon "paw"}}
            <a
              href="/u/{{@outletArgs.user.username}}/characters"
            >{{char.name}}</a>
            {{#if char.is_max_size}}
              <span class="badge max-size-badge">{{i18n
                  "discourse_size.max_size"
                }}</span>
            {{else if char.is_min_size}}
              <span class="badge min-size-badge">{{i18n
                  "discourse_size.min_size"
                }}</span>
            {{/if}}
            &mdash;
            <span class="ds-card-size">{{formatSize
                char.current_size
                char.measurement_system
              }}</span>
          </span>
          {{#if char.is_growing}}
            <span class="ds-card-status growing">{{icon "arrow-up"}}{{i18n
                "discourse_size.growing"
              }}</span>
          {{else if char.is_shrinking}}
            <span class="ds-card-status shrinking">{{icon "arrow-down"}}{{i18n
                "discourse_size.shrinking"
              }}</span>
          {{/if}}
        </div>
      {{/let}}
    {{/if}}
  </template>
}
