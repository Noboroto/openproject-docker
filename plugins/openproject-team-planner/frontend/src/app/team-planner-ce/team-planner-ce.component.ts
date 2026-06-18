import {
  Component,
  Input,
  AfterViewInit,
  ViewChild,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { FullCalendarComponent, FullCalendarModule } from '@fullcalendar/angular';
import { CalendarOptions, EventDropArg } from '@fullcalendar/core';
import { ResourceInput } from '@fullcalendar/resource';
import resourceTimelinePlugin from '@fullcalendar/resource-timeline';
import interactionPlugin from '@fullcalendar/interaction';

interface PlannerData {
  resources: ResourceInput[];
  events: object[];
}

@Component({
  selector: 'op-team-planner-ce',
  templateUrl: './team-planner-ce.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: true,
  imports: [CommonModule, FullCalendarModule],
})
export class TeamPlannerCeComponent implements AfterViewInit {
  @Input('data-project-identifier') projectIdentifier = '';

  @ViewChild('calendar') calendarRef!: FullCalendarComponent;

  error = '';

  private pendingResources: ResourceInput[] | null = null;

  calendarOptions: CalendarOptions = {
    plugins: [resourceTimelinePlugin, interactionPlugin],
    initialView: 'resourceTimelineWeek',
    headerToolbar: {
      left: 'prev,next today',
      center: 'title',
      right: 'resourceTimelineWeek,resourceTimelineMonth',
    },
    editable: true,
    schedulerLicenseKey: 'GPL-My-Project-Is-Open-Source',
    resources: [],
    events: (info: any, successCallback: (events: object[]) => void, failureCallback: (error: Error) => void) => {
      if (!this.projectIdentifier) {
        successCallback([]);
        return;
      }
      const from = info.startStr.slice(0, 10);
      const to = info.endStr.slice(0, 10);
      this.http
        .get<PlannerData>(`/projects/${this.projectIdentifier}/teamplanner_ce/data`, {
          params: { from, to },
        })
        .subscribe({
          next: (data) => {
            this.applyResources(data.resources);
            successCallback(data.events);
            this.error = '';
            this.cdr.markForCheck();
          },
          error: (err) => {
            const msg = err.status === 403 ? 'Access denied.' : 'Failed to load data.';
            this.error = msg;
            this.cdr.markForCheck();
            failureCallback(new Error(msg));
          },
        });
    },
    slotDuration: { days: 1 },
    resourceAreaWidth: '200px',
    resourceAreaHeaderContent: 'Assignee',
    eventDrop: (info: EventDropArg) => this.onEventDrop(info),
    eventClick: (info) => {
      const url = info.event.url;
      if (url) {
        window.location.href = url;
        info.jsEvent.preventDefault();
      }
    },
  };

  constructor(
    private http: HttpClient,
    private cdr: ChangeDetectorRef,
  ) {}

  ngAfterViewInit(): void {
    if (this.pendingResources) {
      this.calendarRef.getApi().setOption('resources', this.pendingResources);
      this.pendingResources = null;
    }
  }

  private applyResources(resources: ResourceInput[]): void {
    if (this.calendarRef) {
      this.calendarRef.getApi().setOption('resources', resources);
    } else {
      this.pendingResources = resources;
    }
  }

  private onEventDrop(info: EventDropArg): void {
    const wpId = info.event.id;
    const csrf =
      (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content ?? '';

    this.http
      .get<{ lockVersion: number }>(`/api/v3/work_packages/${wpId}`)
      .subscribe({
        next: (wp) => {
          const patch = {
            startDate: info.event.startStr?.slice(0, 10) || null,
            dueDate: info.event.endStr?.slice(0, 10) || null,
            lockVersion: wp.lockVersion,
          };
          this.http
            .patch(`/api/v3/work_packages/${wpId}`, patch, {
              headers: { 'X-CSRF-Token': csrf, 'Content-Type': 'application/json' },
            })
            .subscribe({ error: () => info.revert() });
        },
        error: () => info.revert(),
      });
  }
}
