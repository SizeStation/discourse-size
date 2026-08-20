import { fn, get } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import DiscourseSizeCharacterCard from "../../../components/discourse-size-character-card";
import DiscourseSizeFolder from "../../../components/discourse-size-folder";
import DiscourseSizeReorderableList from "../../../components/discourse-size-reorderable-list";

export default RouteTemplate(
  <template>
    {{#if @controller.isCurrentUser}}
      <div class="user-characters-header">
        <h3>{{i18n "discourse_size.my_characters"}}</h3>

        <div class="header-buttons">
          {{#if @controller.siteSettings.discourse_size_help_url}}
            <DButton
              @href={{@controller.siteSettings.discourse_size_help_url}}
              @label="discourse_size.help"
              class="btn-default"
              @icon="circle-question"
            />
          {{/if}}
          <DButton
            @label="discourse_size.shop.visit_shop"
            @icon="discourse-other-tab"
            @href="/size/shop"
            class="btn-default"
          />
          <DButton
            @action={{@controller.createNewFolder}}
            @icon="plus"
            @label="discourse_size.create_folder"
            class="btn-default"
          />
          <DButton
            @action={{@controller.createNewCharacter}}
            @icon="plus"
            @label="discourse_size.create_character"
            class="btn-default"
          />
          {{#if @controller.currentUser.admin}}
            <DButton
              @action={{@controller.showAdminModal}}
              @label="discourse_size.admin.title"
              class="btn-default"
            />
          {{/if}}
        </div>
      </div>
    {{else}}
      <div class="user-characters-header">
        <h3>{{i18n
            "discourse_size.user_characters"
            username=@controller.user.username
          }}</h3>

        <div class="header-buttons">
          {{#if @controller.siteSettings.discourse_size_help_url}}
            <DButton
              @href={{@controller.siteSettings.discourse_size_help_url}}
              @label="discourse_size.help"
              class="btn-default"
              @icon="circle-question"
            />
          {{/if}}
          <DButton
            @label="discourse_size.shop.visit_shop"
            @icon="discourse-other-tab"
            @href="/size/shop"
            class="btn-default"
          />
          <DButton
            @action={{@controller.openRoleplaysModal}}
            @label="discourse_size.roleplays.title"
            @icon="users"
            class="btn-default"
          />
          {{#if @controller.currentUser}}
            <DButton
              @action={{@controller.openGiftingModal}}
              @icon="gift"
              @label="discourse_size.inventory.gift"
              class="btn-default"
            />
          {{/if}}
          {{#if @controller.currentUser.admin}}
            <DButton
              @action={{@controller.showAdminModal}}
              @label="discourse_size.admin.title"
              class="btn-default"
            />
          {{/if}}
        </div>
      </div>
    {{/if}}

    <div class="user-characters-container">
      {{#if @controller.mainCharacter}}
        <div class="main-character-section">
          <DiscourseSizeCharacterCard
            @character={{@controller.mainCharacter}}
            @isCurrentUser={{@controller.isCurrentUser}}
            @userPoints={{@controller.currentUser.discourse_size_points}}
            @onDelete={{@controller.deleteCharacter}}
            @onUpdate={{@controller.updateCharacter}}
            @onAction={{@controller.refreshCharacters}}
          />
        </div>
      {{/if}}

      <DiscourseSizeReorderableList
        @enabled={{@controller.isCurrentUser}}
        @handle=".character-drag-handle, .folder-drag-handle"
        @group="character"
        @onReorder={{@controller.onCharacterReorder}}
        data-top-level="true"
      >
        {{#each @controller.combinedTopLevelList key="id" as |item|}}
          <div
            class="reorderable-item"
            data-id={{item.id}}
            data-type={{item.type}}
          >
            {{#if (eq item.type "character")}}
              <DiscourseSizeCharacterCard
                @character={{item}}
                @isCurrentUser={{@controller.isCurrentUser}}
                @userPoints={{@controller.currentUser.discourse_size_points}}
                @onDelete={{@controller.deleteCharacter}}
                @onUpdate={{@controller.updateCharacter}}
                @onAction={{@controller.refreshCharacters}}
                @showReorderHandle={{@controller.isCurrentUser}}
              />
            {{else}}
              <DiscourseSizeFolder
                @folder={{item}}
                @isCurrentUser={{@controller.isCurrentUser}}
                @onEdit={{fn @controller.editFolder item}}
                @characterCount={{get
                  @controller.organizedCharacterCounts
                  item.id
                }}
              >
                <DiscourseSizeReorderableList
                  @enabled={{@controller.isCurrentUser}}
                  @handle=".character-drag-handle"
                  @group="character"
                  @onReorder={{@controller.onCharacterReorder}}
                  data-folder-id={{item.id}}
                >
                  {{#each
                    (get @controller.organizedCharacters item.id) key="id"
                    as |character|
                  }}
                    <div
                      class="reorderable-item"
                      data-id={{character.id}}
                      data-type="character"
                    >
                      <DiscourseSizeCharacterCard
                        @character={{character}}
                        @isCurrentUser={{@controller.isCurrentUser}}
                        @userPoints={{@controller.currentUser.discourse_size_points}}
                        @onDelete={{@controller.deleteCharacter}}
                        @onUpdate={{@controller.updateCharacter}}
                        @onAction={{@controller.refreshCharacters}}
                        @showReorderHandle={{@controller.isCurrentUser}}
                      />
                    </div>
                  {{/each}}
                </DiscourseSizeReorderableList>
              </DiscourseSizeFolder>
            {{/if}}
          </div>
        {{/each}}
      </DiscourseSizeReorderableList>

      {{#unless @controller.characters.length}}
        <p>{{i18n "discourse_size.no_characters"}}</p>
      {{/unless}}
    </div>
  </template>
);
