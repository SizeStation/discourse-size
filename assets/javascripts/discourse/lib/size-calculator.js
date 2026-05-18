/**
 * Centralized logic for character size calculations and animations.
 * Ensures consistency between character card, details view, and other components.
 */
export function calculateOffset(character, time = new Date()) {
  if (!character || !character.actions || character.actions.length === 0) {
    return parseFloat(character?.current_offset) || 0;
  }

  const actions = character.actions
    .filter((a) => ["grow", "shrink", "set_size"].includes(a.action_type))
    .sort((a, b) => new Date(a.start_time) - new Date(b.start_time));

  if (actions.length === 0) return parseFloat(character.current_offset) || 0;

  // Find the active action at this specific time
  const activeAction = actions.find((a) => {
    if (!a.start_time || !a.end_time) return false;
    const start = new Date(a.start_time);
    const end = new Date(a.end_time);
    return time >= start && time < end;
  });

  if (activeAction) {
    const startT = new Date(activeAction.start_time);
    const endT = new Date(activeAction.end_time);
    const totalDuration = endT.getTime() - startT.getTime();

    if (totalDuration > 0) {
      const elapsed = time.getTime() - startT.getTime();
      const progress = elapsed / totalDuration;

      const startOff = parseFloat(activeAction.start_offset) || 0;
      const endOff = parseFloat(activeAction.end_offset) || 0;

      return startOff + (endOff - startOff) * progress;
    } else {
      return parseFloat(activeAction.end_offset) || 0;
    }
  }

  // Check if we are BEFORE the first action
  if (new Date(actions[0].start_time) > time) {
    return parseFloat(actions[0].start_offset) || 0;
  }

  // Check if we are AFTER the last action
  if (new Date(actions[actions.length - 1].end_time) <= time) {
    return parseFloat(actions[actions.length - 1].end_offset) || 0;
  }

  // We are in a gap between actions. The size should be the end_offset of the most recent past action.
  const lastPastAction = actions
    .slice()
    .reverse()
    .find((a) => new Date(a.end_time) <= time);
  if (lastPastAction) {
    return parseFloat(lastPastAction.end_offset) || 0;
  }

  return parseFloat(character.current_offset) || 0;
}

export function calculateSize(character, time = new Date()) {
  if (!character) return 0;
  return parseFloat(character.base_size) + calculateOffset(character, time);
}

export function calculatePropertyValue(
  character,
  propertyName,
  time = new Date()
) {
  if (!character || !character.actions) return;

  const candidates = character.actions
    .filter(
      (a) =>
        a.action_type === "property_change" &&
        a.item_key === propertyName &&
        a.start_time &&
        a.end_time
    );

  if (candidates.length === 0) return;

  // Find active action (start_time <= now < end_time)
  const active = candidates.find((a) => {
    const start = new Date(a.start_time);
    const end = new Date(a.end_time);
    return time >= start && time < end;
  });

  if (active) {
    const startT = new Date(active.start_time);
    const endT = new Date(active.end_time);
    const total = endT.getTime() - startT.getTime();
    if (total <= 0) return parseFloat(active.end_offset) || 0;
    const progress = (time.getTime() - startT.getTime()) / total;
    return (
      (parseFloat(active.start_offset) || 0) +
      ((parseFloat(active.end_offset) || 0) -
        (parseFloat(active.start_offset) || 0)) *
        progress
    );
  }

  // No active — find most recently expired action
  const expired = candidates
    .filter((a) => new Date(a.end_time) <= time)
    .sort((a, b) => new Date(b.end_time) - new Date(a.end_time));

  if (expired.length > 0) {
    return parseFloat(expired[0].end_offset) || 0;
  }

  // All future — fall through to serialized
  return;
}

export function isAnimating(character, time = new Date()) {
  if (!character || !character.actions) return false;

  return character.actions.some((a) => {
    if (!a.end_time) return false;
    return new Date(a.end_time) > time;
  });
}

export function getTimeRemaining(character, time = new Date()) {
  if (!character || !character.actions) return null;

  const actions = character.actions
    .filter((a) => a.start_time && a.end_time)
    .sort((a, b) => new Date(a.start_time) - new Date(b.start_time));

  const activeAction = actions.find((a) => {
    const start = new Date(a.start_time);
    const end = new Date(a.end_time);
    return time >= start && time < end;
  });

  if (!activeAction) return null;

  const seconds = Math.floor((new Date(activeAction.end_time) - time) / 1000);
  if (seconds <= 0) return null;

  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;

  if (h > 0) return `${h}h ${m}m ${s}s`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}
