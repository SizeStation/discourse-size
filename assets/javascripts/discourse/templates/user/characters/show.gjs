import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DiscourseSizeCharacterCard from "../../../components/discourse-size-character-card";

export default RouteTemplate(
  <template>
    <div class="user-character-show">
      <div class="back-link">
        <LinkTo @route="user.characters.index">
          {{icon "arrow-left"}}
          {{i18n "discourse_size.back_to_characters"}}
        </LinkTo>
      </div>

      <DiscourseSizeCharacterCard
        @character={{@controller.model.character}}
        @isCurrentUser={{@controller.isCurrentUser}}
        @onAction={{@controller.refreshModel}}
      />
    </div>
  </template>
);
