import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
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
            &mdash;
            <span class="ds-card-size">{{formatSize
                char.current_size
                char.measurement_system
              }}</span>
          </span>
          {{#if char.is_growing}}
            <span class="ds-card-status growing">{{icon
                "arrow-up"
              }}Growing</span>
          {{else if char.is_shrinking}}
            <span class="ds-card-status shrinking">{{icon
                "arrow-down"
              }}Shrinking</span>
          {{/if}}
        </div>
      {{/let}}
    {{/if}}
  </template>
}
