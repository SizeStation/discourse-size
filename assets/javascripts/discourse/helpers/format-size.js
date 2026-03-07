import { helper } from "@ember/component/helper";

const METRIC = 1;
const IMPERIAL = 2;

export function formatSize([sizeInCm, system, isChanging]) {
  if (sizeInCm === undefined || sizeInCm === null) {
    return "";
  }
  
  // Default to system metric if not set
  let sys = system === IMPERIAL ? IMPERIAL : METRIC;
  let result = "";

  if (sys === METRIC) {
    if (sizeInCm < 0.0001) {
      result = `${(sizeInCm * 10000000).toFixed(2)} nm`;
    } else if (sizeInCm < 0.1) {
      result = `${(sizeInCm * 10000).toFixed(2)} μm`;
    } else if (sizeInCm < 1) {
      result = `${(sizeInCm * 10).toFixed(2)} mm`;
    } else if (sizeInCm < 100) {
      result = `${sizeInCm.toFixed(2)} cm`;
    } else if (sizeInCm < 100000) {
      result = `${(sizeInCm / 100).toFixed(2)} m`;
    } else if (sizeInCm < 100000000) {
      result = `${(sizeInCm / 100000).toFixed(2)} km`;
    } else if (sizeInCm < 100000000000) {
      result = `${(sizeInCm / 100000000).toFixed(2)} Mm`; // megameters
    } else {
      result = `${(sizeInCm / 100000000000).toFixed(2)} Gm`; // gigameters
    }
  } else {
    // Imperial logic
    let sizeInInches = sizeInCm / 2.54;
    
    if (sizeInInches < 12) {
      result = `${sizeInInches.toFixed(2)} in`;
    } else if (sizeInInches < 36) { // 3 feet
      let feet = Math.floor(sizeInInches / 12);
      let inches = sizeInInches % 12;
      result = `${feet} ft ${inches.toFixed(1)} in`;
    } else if (sizeInInches < 63360) { // 1 mile
      result = `${(sizeInInches / 12).toFixed(2)} ft`; // or Yards, let's just stick to feet if under a mile
    } else {
      let miles = sizeInInches / 63360;
      if (miles > 1000000) {
         // Switch to Lightyears or something funny if massive, but normal imperial works too
         result = `${(miles / 5878625000000).toFixed(4)} lightyears`; // Roughly
         if (parseFloat(result) < 0.0001) result = `${miles.toFixed(2)} mi`; // fall back if lightyears is 0.0000
      } else {
         result = `${miles.toFixed(2)} mi`;
      }
    }
  }

  if (isChanging) {
    result += " (Changing...)";
  }

  return result;
}

export default helper(formatSize);
