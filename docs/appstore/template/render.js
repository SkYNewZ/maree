// Renders the five App Store plates from frame.html.
//
//   cd docs/appstore
//   python3 -m http.server 8791 &
//   npx playwright-cli goto "http://localhost:8791/template/frame.html?out=$PWD/final"
//   npx playwright-cli run-code --filename=template/render.js
//
// Two constraints shape that dance. playwright-cli blocks the file: protocol,
// hence the throwaway HTTP server; and run-code runs in a sandbox with no
// __dirname, no require and no process, so the absolute output directory has
// to arrive through the URL the shell already resolved.
//
// A dedicated context is needed for deviceScaleFactor 2: 660x1434 CSS px
// rendered at 2x is exactly the 1320x2868 App Store Connect expects.
async page => {
  // Plain string surgery: the sandbox has no URL constructor either.
  const opened = page.url();
  const path = opened.split('?')[0];              // the out= value holds slashes too
  const base = path.slice(0, path.lastIndexOf('/') + 1);       // …/template/
  const out = decodeURIComponent((opened.match(/[?&]out=([^&]*)/) || [])[1] || '');
  if (!out) throw new Error('open the template with ?out=<absolute final/ dir>');

  const plates = [
    ['01-rechercher', 'La recherche instantanée, même sans réseau'],
    ['02-fiche', 'Des fiches complètes et illustrées'],
    // Non-breaking space: without it the balanced wrap strands the article
    // ("Explorez les / espèces par groupe").
    ['03-explorer', 'Explorez les espèces par groupe'],
    ['04-galerie', 'Les photos en pleine page'],
    ['05-favoris', 'Vos espèces toujours à portée'],
  ];

  const context = await page.context().browser().newContext({
    viewport: { width: 660, height: 1434 },
    deviceScaleFactor: 2,
  });
  const plate = await context.newPage();

  for (const [name, title] of plates) {
    await plate.goto(
      `${base}frame.html?shot=../raw/${name}.png&title=${encodeURIComponent(title)}`
    );
    await plate.waitForLoadState('networkidle');
    await plate.screenshot({ path: `${out}/${name}.png`, fullPage: true });
  }

  await context.close();
  return `rendered ${plates.length} plates`;
}
