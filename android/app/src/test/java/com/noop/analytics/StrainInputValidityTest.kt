package com.noop.analytics

import com.noop.data.HrSample
import org.junit.Assert.*
import org.junit.Test
import java.util.Locale

/** Same domain cases as StrainInputValidityTests.swift; not a physiological validation. */
class StrainInputValidityTest {
    private val hr = (0 until 600).map { HrSample(deviceId = "test", ts = it.toLong(), bpm = 160) }

    @Test fun compiledSyntheticOracle() {
        for ((name, method) in listOf("edwards" to StrainScorer.Method.EDWARDS, "banister" to StrainScorer.Method.BANISTER)) {
            for (sex in listOf("male", "female")) {
                val score = StrainScorer.strain(hr, maxHR = 190.0, method = method, sex = sex)
                assertNotNull(score)
                println("[effort-oracle] $name|$sex|" + String.format(Locale.ROOT, "%.2f", score!!))
            }
        }
    }

    @Test fun invalidConfigurationIsUnavailableForBothRecipes() {
        for (method in listOf(StrainScorer.Method.EDWARDS, StrainScorer.Method.BANISTER)) {
            for (invalid in listOf(Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY)) {
                assertNull(StrainScorer.strain(hr, maxHR = invalid, method = method))
                assertNull(StrainScorer.strain(hr, restingHR = invalid, method = method))
                assertNull(StrainScorer.strain(hr, method = method, denominator = invalid))
            }
            for (invalid in listOf(1.0, 0.0, -1.0)) {
                assertNull(StrainScorer.strain(hr, method = method, denominator = invalid))
            }
            assertNull(StrainScorer.strain(hr, restingHR = 0.0, method = method))
            assertNull(StrainScorer.strain(hr, restingHR = -1.0, method = method))
        }
    }

    @Test fun oneCorruptReadingRefusesTheWindowRatherThanSilentlyDroppingIt() {
        for (bpm in listOf(0, -1)) {
            val corrupt = hr.toMutableList()
            corrupt[60] = HrSample(deviceId = "test", ts = 60, bpm = bpm)
            for (method in listOf(StrainScorer.Method.EDWARDS, StrainScorer.Method.BANISTER)) {
                assertNull(StrainScorer.strain(corrupt, maxHR = 190.0, method = method))
            }
        }
    }

    @Test fun validZeroAndMissingDataStayDifferentAndDiagnosticIsAvailable() {
        val calm = (0 until 600).map { HrSample(deviceId = "test", ts = it.toLong(), bpm = 60) }
        assertEquals(0.0, StrainScorer.strain(calm, maxHR = 190.0)!!, 0.0)
        assertNull(StrainScorer.strain(emptyList(), maxHR = 190.0))
        assertTrue(StrainScorer.strain(hr, maxHR = 190.0)!! > 0)
        val lines = mutableListOf<String>()
        assertNull(StrainScorer.strain(hr, maxHR = Double.NaN, diag = { lines.add(it) }))
        assertEquals(listOf("[strain-input] refused=invalid_configuration"), lines)
    }

    @Test fun refusalReasonsDistinguishSamplesCoverageAndConfiguration() {
        for (method in listOf(StrainScorer.Method.EDWARDS, StrainScorer.Method.BANISTER)) {
            val rejected = hr.toMutableList()
            rejected[60] = HrSample(deviceId = "test", ts = 60, bpm = 0)
            val lines = mutableListOf<String>()
            assertNull(StrainScorer.strain(rejected, maxHR = 190.0, method = method, diag = { lines.add(it) }))
            assertEquals("[strain-input] refused=rejected_hr_samples count=1", lines.first())
            lines.clear()
            assertNull(StrainScorer.strain(hr.take(19), maxHR = 190.0, method = method, diag = { lines.add(it) }))
            assertEquals("[strain-input] refused=insufficient_coverage", lines.first())
            lines.clear()
            assertNull(StrainScorer.strain(hr, maxHR = 60.0, restingHR = 60.0, method = method, diag = { lines.add(it) }))
            assertEquals("[strain-input] refused=invalid_configuration", lines.first())
        }
    }
}
