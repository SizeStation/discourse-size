export const MIN_SIZE = 1e-35;
export const MAX_SIZE = 1e120;

export function isInfiniteSize(val) {
  if (val === Infinity || val === -Infinity) {
    return true;
  }
  if (typeof val === "string") {
    const s = val.trim().toLowerCase();
    return (
      s === "infinity" ||
      s === "+infinity" ||
      s === "-infinity" ||
      s === "∞" ||
      s === "-∞" ||
      s === "inf" ||
      s === "+inf" ||
      s === "-inf"
    );
  }
  return false;
}

export function clampSize(value) {
  const size = parseFloat(value);
  return Number.isFinite(size)
    ? Math.min(MAX_SIZE, Math.max(MIN_SIZE, size))
    : MIN_SIZE;
}

export function getActionStartSize(character, action) {
  const isNormal = character?.character_type === "normal";
  const raw =
    action.start_size ??
    (isNormal && isInfiniteSize(character?.base_size)
      ? Infinity
      : parseFloat(character?.base_size ?? 0) +
        parseFloat(action.start_offset ?? 0));
  if (isNormal && isInfiniteSize(raw)) {
    return Infinity;
  }
  if (isNormal && Number.isFinite(parseFloat(raw))) {
    const val = parseFloat(raw);
    return val <= 0 ? MIN_SIZE : val;
  }
  return clampSize(raw);
}

export function getActionEndSize(character, action) {
  const isNormal = character?.character_type === "normal";
  const raw =
    action.end_size ??
    (isNormal && isInfiniteSize(character?.base_size)
      ? Infinity
      : parseFloat(character?.base_size ?? 0) +
        parseFloat(action.end_offset ?? 0));
  if (isNormal && isInfiniteSize(raw)) {
    return Infinity;
  }
  if (isNormal && Number.isFinite(parseFloat(raw))) {
    const val = parseFloat(raw);
    return val <= 0 ? MIN_SIZE : val;
  }
  return clampSize(raw);
}

export function getSizeActions(character) {
  return (character?.actions || [])
    .filter(
      (a) =>
        ["grow", "shrink", "set_size"].includes(a.action_type) &&
        a.start_time &&
        a.end_time
    )
    .sort(
      (a, b) =>
        new Date(a.start_time) - new Date(b.start_time) ||
        (a.id || 0) - (b.id || 0)
    );
}

export function calculateTargetSize(character) {
  const isNormal = character?.character_type === "normal";
  if (!Array.isArray(character?.actions)) {
    const raw =
      character?.target_size ??
      character?.current_size ??
      (isNormal && isInfiniteSize(character?.base_size)
        ? Infinity
        : parseFloat(character?.base_size ?? 0) +
          parseFloat(
            character?.target_offset ?? character?.current_offset ?? 0
          ));
    if (isNormal && isInfiniteSize(raw)) {
      return Infinity;
    }
    if (isNormal && Number.isFinite(parseFloat(raw))) {
      const val = parseFloat(raw);
      return val <= 0 ? MIN_SIZE : val;
    }
    return clampSize(raw);
  }

  const actions = character.actions
    .filter((action) =>
      ["grow", "shrink", "set_size"].includes(action.action_type)
    )
    .sort(
      (a, b) =>
        new Date(a.created_at || a.start_time || 0) -
          new Date(b.created_at || b.start_time || 0) ||
        (a.id || 0) - (b.id || 0)
    );
  if (actions.length) {
    return getActionEndSize(character, actions[actions.length - 1]);
  }
  if (isNormal && isInfiniteSize(character.base_size)) {
    return Infinity;
  }
  if (isNormal && Number.isFinite(parseFloat(character.base_size))) {
    return parseFloat(character.base_size);
  }
  return clampSize(character.base_size);
}

export function calculateSize(character, time = new Date()) {
  if (!character) {
    return 0;
  }

  const isNormal = character.character_type === "normal";

  // Omitted actions mean a summary payload, not an empty history.
  if (!Array.isArray(character.actions)) {
    const raw =
      character.current_size ??
      character.target_size ??
      (isNormal && isInfiniteSize(character.base_size)
        ? Infinity
        : parseFloat(character.base_size ?? 0) +
          parseFloat(character.current_offset ?? character.target_offset ?? 0));
    if (isNormal && isInfiniteSize(raw)) {
      return Infinity;
    }
    if (isNormal && Number.isFinite(parseFloat(raw))) {
      const val = parseFloat(raw);
      return val <= 0 ? MIN_SIZE : val;
    }
    return clampSize(raw);
  }

  const actions = getSizeActions(character);
  if (!actions.length) {
    if (isNormal && isInfiniteSize(character.base_size)) {
      return Infinity;
    }
    if (isNormal && Number.isFinite(parseFloat(character.base_size))) {
      return parseFloat(character.base_size);
    }
    return clampSize(character.base_size);
  }

  const active = actions.find(
    (a) => time >= new Date(a.start_time) && time < new Date(a.end_time)
  );
  if (active) {
    const start = new Date(active.start_time);
    const end = new Date(active.end_time);
    const progress = (time - start) / (end - start);
    const startSize = getActionStartSize(character, active);
    const endSize = getActionEndSize(character, active);
    if (startSize === Infinity || endSize === Infinity) {
      return Infinity;
    }
    if (progress <= 0) {
      return startSize;
    }
    if (progress >= 1) {
      return endSize;
    }
    // Subtracting endpoints first loses a tiny destination when shrinking.
    const interpolated = (1 - progress) * startSize + progress * endSize;
    return isNormal ? interpolated : clampSize(interpolated);
  }

  if (time < new Date(actions[0].start_time)) {
    return getActionStartSize(character, actions[0]);
  }

  const past = actions
    .slice()
    .reverse()
    .find((a) => new Date(a.end_time) <= time);
  if (past) {
    return getActionEndSize(character, past);
  }

  if (isNormal && isInfiniteSize(character.base_size)) {
    return Infinity;
  }
  if (isNormal && Number.isFinite(parseFloat(character.base_size))) {
    return parseFloat(character.base_size);
  }
  return clampSize(character.base_size);
}

/** Compatibility only: adding this offset back to a large base can lose precision. */
export function calculateOffset(character, time = new Date()) {
  if (isInfiniteSize(character?.base_size)) {
    return 0;
  }
  const base = parseFloat(character?.base_size);
  return calculateSize(character, time) - (Number.isFinite(base) ? base : 0);
}

export function calculatePropertyValue(
  character,
  propertyName,
  time = new Date()
) {
  if (!character || !character.actions) {
    return;
  }

  const candidates = character.actions.filter(
    (a) =>
      a.action_type === "property_change" &&
      a.item_key === propertyName &&
      a.start_time &&
      a.end_time
  );

  if (candidates.length === 0) {
    return;
  }

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
    if (total <= 0) {
      return parseFloat(active.end_offset) || 0;
    }
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
    .sort(
      (a, b) =>
        new Date(b.end_time) - new Date(a.end_time) || (b.id || 0) - (a.id || 0)
    );

  if (expired.length > 0) {
    return parseFloat(expired[0].end_offset) || 0;
  }

  // All future — fall through to serialized
  return;
}

export function isAnimating(character, time = new Date()) {
  if (!character || !character.actions) {
    return false;
  }

  return character.actions.some((a) => {
    if (!a.end_time) {
      return false;
    }
    return new Date(a.end_time) > time;
  });
}

export function getTimeRemaining(character, time = new Date()) {
  if (!character || !character.actions) {
    return null;
  }

  const actions = character.actions
    .filter((a) => a.start_time && a.end_time)
    .sort((a, b) => new Date(a.start_time) - new Date(b.start_time));

  const activeAction = actions.find((a) => {
    const start = new Date(a.start_time);
    const end = new Date(a.end_time);
    return time >= start && time < end;
  });

  if (!activeAction) {
    return null;
  }

  const seconds = Math.floor((new Date(activeAction.end_time) - time) / 1000);
  if (seconds <= 0) {
    return null;
  }

  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;

  if (h > 0) {
    return `${h}h ${m}m ${s}s`;
  }
  if (m > 0) {
    return `${m}m ${s}s`;
  }
  return `${s}s`;
}
