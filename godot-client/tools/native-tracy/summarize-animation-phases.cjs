'use strict';

// Input is tracy-csvexport -u -f NWN.Rig. -s <tab> capture.tracy.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { table } = require('./trace-table.cjs');

const prefix = 'NWN.Rig.';
const phases = ['SetupAndClocks', 'SampleAndBlend', 'PoseApply'];
const known = new Set(['SampledFrame', 'Advance', 'Process', 'TransformPropagation', ...phases]);

function number(value) {
	assert.match(value, /^-?\d+$/);
	const result = Number(value);
	assert.ok(Number.isSafeInteger(result), 'Trace timestamp exceeds integer precision');
	return result;
}

function inOrder(spans) {
	for (let i = 1; i < spans.length; i++) {
		assert.ok(spans[i - 1].end <= spans[i].start, 'Expected serial sibling zones');
	}
}

function assign(parents, children) {
	inOrder(parents);
	inOrder(children);
	const groups = parents.map(() => []);
	let index = 0;
	for (const child of children) {
		while (index < parents.length && child.start >= parents[index].end) index++;
		const parent = parents[index];
		assert.ok(parent && parent.start <= child.start && child.end <= parent.end, `Unowned phase ${child.name}`);
		groups[index].push(child.name);
	}
	return groups;
}

function sum(spans) {
	return spans.reduce((total, span) => total + span.duration, 0);
}

function frameCounts(rows) {
	const named = name => rows.filter(span => span.name === name);
	const advances = named('Advance');
	const processes = named('Process');
	const applications = named('PoseApply');
	const propagation = named('TransformPropagation');
	assert.ok(advances.length, 'Sampled frame lacks rig advances');
	for (const group of assign(advances, processes)) assert.deepEqual(group, ['Process']);
	for (const group of assign(processes, rows.filter(row => phases.includes(row.name)))) {
		assert.deepEqual(group, group.length === 1 ? phases.slice(0, 1) : phases);
	}
	assign(applications, propagation);
	const advanceNs = sum(advances);
	const setupNs = sum(named('SetupAndClocks'));
	const samplingNs = sum(named('SampleAndBlend'));
	const applyNs = sum(applications);
	const propagationNs = sum(propagation);
	return {
		advances: advances.length, poseApplications: applications.length, propagationCalls: propagation.length,
		advanceNs, setupNs, samplingNs, exclusivePoseApplyNs: applyNs - propagationNs, propagationNs,
		remainderNs: advanceNs - setupNs - samplingNs - applyNs,
	};
}

function summarize(text, startNs = -Infinity, endNs = Infinity) {
	assert.ok(startNs < endNs, 'Window end must follow its start');
	const rows = table(text, 'cpu').map(row => {
		assert.ok(row.name.startsWith(prefix), 'Use a phase-filtered CPU export');
		const name = row.name.slice(prefix.length);
		assert.ok(known.has(name), `Unexpected phase ${row.name}`);
		assert.match(row.thread, /^\d+$/);
		const start = number(row.ns_since_start);
		const duration = number(row.exec_time_ns);
		return { name, start, end: start + duration, duration, thread: row.thread };
	}).sort((a, b) => a.start - b.start);
	const markers = rows.filter(row => row.name === 'SampledFrame' && row.duration >= 0);
	assert.ok(markers.length >= 2, 'At least two complete sampled-frame markers are required');
	inOrder(markers);
	const measured = [];
	let cursor = 0;
	for (let i = 0; i + 1 < markers.length; i++) {
		const begin = markers[i];
		const next = markers[i + 1];
		if (begin.start < startNs || next.start > endNs) continue;
		assert.equal(begin.thread, next.thread, 'Expected a single rig processing thread');
		while (cursor < rows.length && rows[cursor].start < begin.start) cursor++;
		const events = [];
		while (cursor < rows.length && rows[cursor].start < next.start) {
			const event = rows[cursor++];
			assert.equal(event.thread, begin.thread, 'Phase event belongs to another thread');
			assert.ok(event.duration >= 0 && event.end <= next.start, 'Incomplete or boundary-crossing sampled frame');
			if (event.name !== 'SampledFrame') events.push(event);
		}
		measured.push({ firstNs: begin.start, nextNs: next.start, ...frameCounts(events) });
	}
	assert.ok(measured.length, 'No complete sampled frames fall in this window');
	const counts = Object.fromEntries(['advances', 'poseApplications', 'propagationCalls'].map(key => [key, measured.reduce((total, frame) => total + frame[key], 0)]));
	const keys = ['advanceNs', 'setupNs', 'samplingNs', 'exclusivePoseApplyNs', 'propagationNs', 'remainderNs'];
	const msPerSampledFrame = Object.fromEntries(keys.map(key => {
		const values = measured.map(frame => frame[key]).sort((a, b) => a - b);
		const mean = values.reduce((total, value) => total + value, 0) / values.length;
		const percentile = p => values[Math.ceil(values.length * p) - 1] / 1e6;
		return [key.slice(0, -2), { mean: mean / 1e6, median: percentile(0.5), p95: percentile(0.95) }];
	}));
	return { sampledFrames: measured.length, firstNs: measured[0].firstNs, nextBoundaryNs: measured.at(-1).nextNs, counts, msPerSampledFrame };
}

if (require.main === module) {
	const [input, start, end, extra] = process.argv.slice(2);
	assert.ok(input && extra === undefined && (start === undefined) === (end === undefined), 'Usage: summarize-animation-phases.cjs <phase.tsv> [start-ns end-ns]');
	const source = fs.readFileSync(input, 'utf8');
	console.log(JSON.stringify(start === undefined ? summarize(source) : summarize(source, number(start), number(end)), null, 2));
}

module.exports = { summarize };
