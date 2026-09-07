import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

<template>
  <li class="user-main-nav-outlet discourse-size-characters characters">
    <LinkTo @route="user.characters">
      {{icon "paw"}}
      <span>{{i18n "discourse_size.characters"}}</span>
    </LinkTo>
  </li>
</template>
