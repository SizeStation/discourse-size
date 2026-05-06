/**
 * Centralized logic for character size calculations and animations.
 * Ensures consistency between character card, details view, and other components.
 */
export function calculateOffset(character, time = new Date()) {
  if (!character || !character.actions || character.actions.length === 0) {
    return parseFloat(character?.current_offset) || 0;
  }
  
  const actions = character.actions
    .filter(a => ["grow", "shrink", "set_size"].includes(a.action_type))
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
  const lastPastAction = actions.slice().reverse().find(a => new Date(a.end_time) <= time);
  if (lastPastAction) {
    return parseFloat(lastPastAction.end_offset) || 0;
  }

  return parseFloat(character.current_offset) || 0;
}

export function calculateSize(character, time = new Date()) {
  if (!character) return 0;
  return parseFloat(character.base_size) + calculateOffset(character, time);
}

export function isAnimating(character, time = new Date()) {
  if (!character || !character.actions) return false;
  
  return character.actions.some(a => {
    if (!a.end_time) return false;
    return new Date(a.end_time) > time;
  });
}

export function getTimeRemaining(character, time = new Date()) {
  if (!character || !character.actions) return null;
  
  const lastAction = character.actions
    .slice()
    .filter((a) => a.end_time)
    .sort((a, b) => new Date(b.end_time) - new Date(a.end_time))[0];

  if (!lastAction || new Date(lastAction.end_time) <= time) return null;

  const seconds = Math.floor((new Date(lastAction.end_time) - time) / 1000);
  if (seconds <= 0) return null;

  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;

  if (h > 0) return `${h}h ${m}m ${s}s`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}
