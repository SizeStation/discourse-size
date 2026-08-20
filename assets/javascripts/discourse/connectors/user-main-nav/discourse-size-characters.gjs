import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { classNames, tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";

@tagName("li")
@classNames("user-main-nav-outlet", "discourse-size-characters")
export default class DiscourseSizeCharactersConnector extends Component {
  <template>
    <li class="user-main-nav-outlet characters">
      <LinkTo @route="user.characters">
        {{icon "paw"}}
        <span>Characters</span>
      </LinkTo>
    </li>
  </template>
}
