import { createApplication } from '@angular/platform-browser';
import { createCustomElement } from '@angular/elements';
import { provideHttpClient } from '@angular/common/http';
import { TeamPlannerCeComponent } from './app/team-planner-ce/team-planner-ce.component';

(async () => {
  const app = await createApplication({
    providers: [provideHttpClient()],
  });

  const element = createCustomElement(TeamPlannerCeComponent, { injector: app.injector });
  customElements.define('op-team-planner-ce', element);
})();
