// Split-flap board: each cell riffles through the drum and settles on its
// value, row by row. Reduced motion shows the final values at once.
(() => {
  const DRUM = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:%";
  const TICK = 55;
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const cells = [...document.querySelectorAll("[data-flap]")];
  cells.forEach((cell, index) => {
    const value = cell.dataset.flap.toUpperCase();
    const width = Math.max(Number(cell.dataset.width) || value.length, value.length);
    const target = value.padEnd(width, " ");
    cell.setAttribute("aria-label", value);

    const row = document.createElement("span");
    row.className = "flaps";
    row.setAttribute("aria-hidden", "true");
    const flaps = [...target].map(() => {
      const flap = document.createElement("span");
      flap.className = "flap flap--blank";
      flap.textContent = " ";
      row.appendChild(flap);
      return flap;
    });
    cell.appendChild(row);

    const settle = (flap, char) => {
      flap.textContent = char;
      flap.classList.toggle("flap--blank", char === " ");
    };

    if (reduce) {
      flaps.forEach((flap, i) => settle(flap, target[i]));
      return;
    }

    const rowIndex = cell.closest(".board__row")
      ? [...cell.closest(".board__table").children].indexOf(cell.closest(".board__row"))
      : 0;
    flaps.forEach((flap, i) => {
      const goal = target[i];
      const steps = goal === " " ? 0 : 6 + ((index * 7 + i * 3) % 9);
      let step = 0;
      const start = rowIndex * 260 + i * 35;
      const turn = () => {
        const char = step < steps ? DRUM[(DRUM.indexOf(goal) - steps + step + DRUM.length) % DRUM.length] : goal;
        settle(flap, char);
        flap.classList.remove("is-turning");
        void flap.offsetWidth;
        flap.classList.add("is-turning");
        if (step++ < steps) setTimeout(turn, TICK);
      };
      setTimeout(turn, start);
    });
  });

  // Live local clock in the board header.
  const clock = document.getElementById("clock");
  if (clock) {
    const fmt = new Intl.DateTimeFormat(undefined, { hour: "2-digit", minute: "2-digit", hour12: false });
    const tick = () => {
      const now = new Date();
      clock.textContent = fmt.format(now);
      clock.dateTime = now.toISOString();
    };
    tick();
    setInterval(tick, 15000);
  }

  // Copy the Homebrew command.
  document.querySelectorAll("[data-copy]").forEach((button) => {
    button.addEventListener("click", async () => {
      const source = document.getElementById(button.dataset.copy);
      try {
        await navigator.clipboard.writeText(source.textContent.trim());
        button.textContent = "Copied";
        button.classList.add("is-done");
      } catch {
        const range = document.createRange();
        range.selectNodeContents(source);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
        button.textContent = "Selected";
      }
      setTimeout(() => {
        button.textContent = "Copy";
        button.classList.remove("is-done");
      }, 1800);
    });
  });
})();
